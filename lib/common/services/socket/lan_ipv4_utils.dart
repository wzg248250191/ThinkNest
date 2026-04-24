import 'dart:io';
import 'package:flutter/services.dart';

/// 本机 IPv4 局域网网段信息
///
/// 说明：
/// - 使用“本机 IP + 子网掩码”计算网络地址与广播地址
/// - 用于按真实掩码判断目标服务器是否在同一局域网
class LanIpv4Network {
  /// 创建一条本机 IPv4 网段信息
  const LanIpv4Network({
    required this.interfaceName,
    required this.ipInt,
    required this.maskInt,
    required this.maskSource,
  });

  /// 网卡名（如 WLAN/eth0）
  final String interfaceName;

  /// 本机 IPv4（32 位整型）
  final int ipInt;

  /// 子网掩码（32 位整型）
  final int maskInt;

  /// 子网掩码来源（android_channel/ip_addr/ip_route/proc/default）
  final String maskSource;

  /// 本机 IPv4 字符串
  String get ip => LanIpv4Utils.intToIpv4(ipInt);

  /// 子网掩码字符串
  String get mask => LanIpv4Utils.intToIpv4(maskInt);

  /// 网络地址（IP & 掩码）
  int get networkInt => ipInt & maskInt;

  /// 广播地址（network | ~mask）
  int get broadcastInt => networkInt | (~maskInt & 0xFFFFFFFF);

  /// 网络地址字符串
  String get network => LanIpv4Utils.intToIpv4(networkInt);

  /// 广播地址字符串
  String get broadcast => LanIpv4Utils.intToIpv4(broadcastInt);

  /// 调试摘要
  String get debugSummary => '$ip/$mask(net=$network,src=$maskSource,if=$interfaceName)';
}

/// IPv4 局域网判断工具
///
/// 说明：
/// - 通过“IP 与子网掩码位运算”判断同一局域网，避免仅按 /24 前缀造成误判
class LanIpv4Utils {
  static const MethodChannel _networkChannel = MethodChannel('think_nest/network');
  static const Duration _localNetworksCacheTtl = Duration(seconds: 5);
  static const Duration _localNetworksFallbackMaxAge = Duration(seconds: 30);
  static List<LanIpv4Network> _cachedLocalNetworks = const <LanIpv4Network>[];
  static DateTime? _cachedLocalNetworksAt;

  /// 获取本机所有可用的私网 IPv4 网段信息
  static Future<List<LanIpv4Network>> localNetworks() async {
    final DateTime now = DateTime.now();
    if (_hasFreshLocalNetworksCache(now)) {
      return _cachedLocalNetworks;
    }
    try {
      final List<LanIpv4Network> result = await _loadLocalNetworksOnce();
      if (result.isNotEmpty) {
        _updateLocalNetworksCache(result, now);
        return result;
      }
      // 关键逻辑：本次采集为空时，优先回退到“最近一次有效网段”，避免网络切换瞬时导致恢复连接误拒绝。
      if (_hasFallbackLocalNetworksCache(now)) {
        return _cachedLocalNetworks;
      }
      return const <LanIpv4Network>[];
    } catch (_) {
      // 关键逻辑：采集异常时若存在最近有效网段，继续使用缓存做严格判定；无缓存时仍按严格模式返回空。
      if (_hasFallbackLocalNetworksCache(now)) {
        return _cachedLocalNetworks;
      }
      return const <LanIpv4Network>[];
    }
  }

  /// 单次读取本机网段信息（不含缓存逻辑）
  static Future<List<LanIpv4Network>> _loadLocalNetworksOnce() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final Map<String, int> interfaceMasks = <String, int>{
        ...await _loadInterfaceMasksFromProc(),
        ...await _loadInterfaceMasksFromIpRoute(),
      };
      final Map<String, int> androidChannelIpMasks = await _loadIpMasksFromAndroidChannel();
      final Map<String, int> ipAddrIpMasks = await _loadIpMasksFromIpAddr();
      final Map<String, int> windowsIpMasks = await _loadIpMasksFromWindowsIpconfig();

      final List<LanIpv4Network> result = <LanIpv4Network>[];
      for (final NetworkInterface itf in interfaces) {
        for (final InternetAddress addr in itf.addresses) {
          final int? ipInt = tryParseIpv4(addr.address);
          if (ipInt == null || !_isPrivateIpv4Int(ipInt)) {
            continue;
          }

          // 关键逻辑：优先使用“按 IP 精确匹配”的掩码，避免接口名映射不一致时退化为错误的 /24。
          final String ip = addr.address;
          int maskInt;
          String maskSource;
          if (androidChannelIpMasks.containsKey(ip)) {
            maskInt = androidChannelIpMasks[ip]!;
            maskSource = 'android_channel';
          } else if (ipAddrIpMasks.containsKey(ip)) {
            maskInt = ipAddrIpMasks[ip]!;
            maskSource = 'ip_addr';
          } else if (windowsIpMasks.containsKey(ip)) {
            maskInt = windowsIpMasks[ip]!;
            maskSource = 'windows_ipconfig';
          } else if (interfaceMasks.containsKey(itf.name)) {
            maskInt = interfaceMasks[itf.name]!;
            maskSource = 'iface_route';
          } else {
            maskInt = _defaultMaskInt(ipInt);
            maskSource = 'default';
          }
          result.add(
            LanIpv4Network(
              interfaceName: itf.name,
              ipInt: ipInt,
              maskInt: maskInt,
              maskSource: maskSource,
            ),
          );
        }
      }
      return result;
    } catch (_) {
      return const <LanIpv4Network>[];
    }
  }

  /// 判断本机网段缓存是否仍在短时有效期内
  static bool _hasFreshLocalNetworksCache(DateTime now) {
    final DateTime? cachedAt = _cachedLocalNetworksAt;
    if (cachedAt == null || _cachedLocalNetworks.isEmpty) {
      return false;
    }
    return now.difference(cachedAt) <= _localNetworksCacheTtl;
  }

  /// 判断本机网段缓存是否仍可作为失败回退值
  static bool _hasFallbackLocalNetworksCache(DateTime now) {
    final DateTime? cachedAt = _cachedLocalNetworksAt;
    if (cachedAt == null || _cachedLocalNetworks.isEmpty) {
      return false;
    }
    return now.difference(cachedAt) <= _localNetworksFallbackMaxAge;
  }

  /// 更新本机网段缓存
  static void _updateLocalNetworksCache(List<LanIpv4Network> localNetworks, DateTime now) {
    _cachedLocalNetworks = List<LanIpv4Network>.unmodifiable(localNetworks);
    _cachedLocalNetworksAt = now;
  }

  /// 判断目标 IPv4 是否与任一本机网段同属局域网
  static bool isInSameLan(String targetIp, List<LanIpv4Network> localNetworks) {
    final int? targetInt = tryParseIpv4(targetIp);
    if (targetInt == null || !_isPrivateIpv4Int(targetInt)) {
      return false;
    }
    for (final LanIpv4Network lan in localNetworks) {
      if ((targetInt & lan.maskInt) == lan.networkInt) {
        return true;
      }
    }
    return false;
  }

  /// 将网段列表格式化为便于排查的日志字符串
  static String formatNetworksForLog(List<LanIpv4Network> localNetworks) {
    return localNetworks.map((LanIpv4Network lan) => lan.debugSummary).join(', ');
  }

  /// 将 IPv4 字符串解析为 32 位整型，失败返回 null
  static int? tryParseIpv4(String ip) {
    final List<String> parts = ip.split('.');
    if (parts.length != 4) {
      return null;
    }
    int value = 0;
    for (final String part in parts) {
      final int? n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) {
        return null;
      }
      value = (value << 8) | n;
    }
    return value & 0xFFFFFFFF;
  }

  /// 将 32 位整型 IPv4 转为字符串
  static String intToIpv4(int value) {
    final int v = value & 0xFFFFFFFF;
    return '${(v >> 24) & 0xFF}.${(v >> 16) & 0xFF}.${(v >> 8) & 0xFF}.${v & 0xFF}';
  }

  /// 判断 IPv4 整型是否为私网地址
  static bool _isPrivateIpv4Int(int ipInt) {
    final int a = (ipInt >> 24) & 0xFF;
    final int b = (ipInt >> 16) & 0xFF;
    if (a == 10) {
      return true;
    }
    if (a == 192 && b == 168) {
      return true;
    }
    if (a == 172 && b >= 16 && b <= 31) {
      return true;
    }
    return false;
  }

  /// 读取 Android/Linux 的 /proc/net/route，按网卡提取子网掩码
  static Future<Map<String, int>> _loadInterfaceMasksFromProc() async {
    if (!(Platform.isAndroid || Platform.isLinux)) {
      return const <String, int>{};
    }
    final File f = File('/proc/net/route');
    if (!await f.exists()) {
      return const <String, int>{};
    }

    final Map<String, int> byInterface = <String, int>{};
    final List<String> lines = await f.readAsLines();
    for (final String line in lines.skip(1)) {
      final List<String> cols = line.trim().split(RegExp(r'\s+'));
      if (cols.length < 8) {
        continue;
      }
      final String iface = cols[0];
      final String destinationHex = cols[1];
      final String maskHex = cols[7];
      if (destinationHex == '00000000') {
        continue;
      }
      final int? mask = _parseLittleEndianHexIpv4(maskHex);
      if (mask == null || mask == 0) {
        continue;
      }
      final int old = byInterface[iface] ?? 0;
      // 关键逻辑：同一网卡可能有多条路由，优先保留“1 位数更多（掩码更长）”的子网掩码。
      if (_bitCount(mask) > _bitCount(old)) {
        byInterface[iface] = mask;
      }
    }
    return byInterface;
  }

  /// 读取 Android/Linux 的 `ip route` 输出，按网卡提取子网掩码
  static Future<Map<String, int>> _loadInterfaceMasksFromIpRoute() async {
    if (!(Platform.isAndroid || Platform.isLinux)) {
      return const <String, int>{};
    }
    try {
      final ProcessResult r = await Process.run('ip', <String>['route']);
      if (r.exitCode != 0) {
        return const <String, int>{};
      }
      final String text = '${r.stdout}\n${r.stderr}';
      final List<String> lines = text.split(RegExp(r'\r?\n'));
      final Map<String, int> byInterface = <String, int>{};

      final RegExp routeRegex = RegExp(
        r'^(\d{1,3}(?:\.\d{1,3}){3})/(\d{1,2})\s+dev\s+([^\s]+)',
      );
      for (final String rawLine in lines) {
        final String line = rawLine.trim();
        final Match? m = routeRegex.firstMatch(line);
        if (m == null) {
          continue;
        }
        final String destination = m.group(1)!;
        final int? prefix = int.tryParse(m.group(2)!);
        final String iface = m.group(3)!;
        if (prefix == null || prefix <= 0 || prefix > 32) {
          continue;
        }
        // 关键逻辑：忽略 default/主机路由，避免把 /32 等非网段路由误当成接口子网掩码。
        if (prefix >= 31) {
          continue;
        }
        final int? destinationInt = tryParseIpv4(destination);
        if (destinationInt == null || !_isPrivateIpv4Int(destinationInt)) {
          continue;
        }
        final int mask = _prefixToMask(prefix);
        final int old = byInterface[iface] ?? 0;
        // 关键逻辑：同网卡多条私网路由时，优先使用更“宽”的网段，避免被更窄路由误导成 /24。
        if (old == 0 || _bitCount(mask) < _bitCount(old)) {
          byInterface[iface] = mask;
        }
      }
      return byInterface;
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// 读取 Android/Linux 的 `ip -f inet addr show` 输出，按 IP 提取前缀掩码
  static Future<Map<String, int>> _loadIpMasksFromIpAddr() async {
    if (!(Platform.isAndroid || Platform.isLinux)) {
      return const <String, int>{};
    }
    try {
      final ProcessResult r = await Process.run('ip', <String>['-f', 'inet', 'addr', 'show']);
      if (r.exitCode != 0) {
        return const <String, int>{};
      }
      final String text = '${r.stdout}\n${r.stderr}';
      final List<String> lines = text.split(RegExp(r'\r?\n'));
      final RegExp inetRegex = RegExp(r'\s+inet\s+(\d{1,3}(?:\.\d{1,3}){3})/(\d{1,2})\b');

      final Map<String, int> byIp = <String, int>{};
      for (final String line in lines) {
        final Match? m = inetRegex.firstMatch(line);
        if (m == null) {
          continue;
        }
        final String ip = m.group(1)!;
        final int? prefix = int.tryParse(m.group(2)!);
        if (prefix == null || prefix <= 0 || prefix > 32) {
          continue;
        }
        final int? ipInt = tryParseIpv4(ip);
        if (ipInt == null || !_isPrivateIpv4Int(ipInt)) {
          continue;
        }
        byIp[ip] = _prefixToMask(prefix);
      }
      return byIp;
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// 通过 Android 原生通道读取 IPv4 前缀信息，并按 IP 转换为子网掩码
  static Future<Map<String, int>> _loadIpMasksFromAndroidChannel() async {
    if (!Platform.isAndroid) {
      return const <String, int>{};
    }
    try {
      final dynamic result = await _networkChannel.invokeMethod('getLocalIpv4Prefixes');
      if (result is! List) {
        return const <String, int>{};
      }
      final Map<String, int> out = <String, int>{};
      for (final dynamic item in result) {
        if (item is! Map) {
          continue;
        }
        final dynamic ipRaw = item['ip'];
        final dynamic prefixRaw = item['prefixLength'];
        final String? ip = ipRaw is String ? ipRaw : null;
        final int? prefix = prefixRaw is int ? prefixRaw : int.tryParse('$prefixRaw');
        if (ip == null || prefix == null || prefix <= 0 || prefix > 32) {
          continue;
        }
        final int? ipInt = tryParseIpv4(ip);
        if (ipInt == null || !_isPrivateIpv4Int(ipInt)) {
          continue;
        }
        out[ip] = _prefixToMask(prefix);
      }
      return out;
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// 读取 Windows ipconfig 输出，按 IPv4 提取子网掩码
  static Future<Map<String, int>> _loadIpMasksFromWindowsIpconfig() async {
    if (!Platform.isWindows) {
      return const <String, int>{};
    }
    try {
      final ProcessResult r = await Process.run('ipconfig', <String>[]);
      if (r.exitCode != 0) {
        return const <String, int>{};
      }
      final String text = '${r.stdout}\n${r.stderr}';
      final List<String> lines = text.split(RegExp(r'\r?\n'));
      final RegExp ipv4Regex = RegExp(r'(\d{1,3}\.){3}\d{1,3}');

      String? currentIp;
      final Map<String, int> out = <String, int>{};
      for (final String line in lines) {
        final bool hasIpv4Keyword = line.contains('IPv4') || line.contains('IPv4 地址');
        final bool hasMaskKeyword = line.contains('Subnet Mask') || line.contains('子网掩码');
        if (hasIpv4Keyword) {
          final Match? m = ipv4Regex.firstMatch(line);
          currentIp = m?.group(0);
          continue;
        }
        if (hasMaskKeyword && currentIp != null) {
          final Match? m = ipv4Regex.firstMatch(line);
          final String? mask = m?.group(0);
          final int? maskInt = mask == null ? null : tryParseIpv4(mask);
          if (maskInt != null) {
            out[currentIp] = maskInt;
          }
          currentIp = null;
        }
      }
      return out;
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// 解析 /proc/net/route 中“小端序”十六进制 IPv4
  static int? _parseLittleEndianHexIpv4(String raw) {
    final String s = raw.trim();
    if (!RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(s)) {
      return null;
    }
    final int x = int.parse(s, radix: 16);
    final int b0 = x & 0xFF;
    final int b1 = (x >> 8) & 0xFF;
    final int b2 = (x >> 16) & 0xFF;
    final int b3 = (x >> 24) & 0xFF;
    return ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & 0xFFFFFFFF;
  }

  /// 私网掩码兜底值
  static int _defaultMaskInt(int ipInt) {
    final int a = (ipInt >> 24) & 0xFF;
    final int b = (ipInt >> 16) & 0xFF;
    if (a == 10) {
      return tryParseIpv4('255.0.0.0')!;
    }
    if (a == 172 && b >= 16 && b <= 31) {
      return tryParseIpv4('255.240.0.0')!;
    }
    return tryParseIpv4('255.255.255.0')!;
  }

  /// 将前缀长度转换为掩码整数
  static int _prefixToMask(int prefix) {
    if (prefix <= 0) {
      return 0;
    }
    if (prefix >= 32) {
      return 0xFFFFFFFF;
    }
    return ((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF);
  }

  /// 统计 32 位整数中的 1 位个数
  static int _bitCount(int v) {
    int x = v & 0xFFFFFFFF;
    int c = 0;
    while (x != 0) {
      x &= (x - 1);
      c++;
    }
    return c;
  }
}
