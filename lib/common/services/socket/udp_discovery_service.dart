import 'dart:async';
import 'dart:io';

import '../../index.dart';

/// UDP发现服务
/// 用于自动发现局域网内的PC服务器
class UdpDiscoveryService {
  /// UDP Socket
  RawDatagramSocket? _socket;
  
  /// 发现的服务器列表
  final List<DiscoveredServer> _discoveredServers = [];

  /// 本机当前可用的 IPv4 /24 网段前缀缓存（例如 192.168.101）
  List<String> _localIpv4Prefixes = const <String>[];
  
  /// 扫描完成通知（用于提前结束扫描）
  Completer<void>? _discoveryDoneCompleter;
  
  /// 是否正在扫描
  bool _isScanning = false;
  
  /// UDP Echo端口（服务器端）
  static const int udpEchoPort = 7000;
  
  /// iPad Server TCP端口
  static const int iPadServerPort = 8000;
  
  /// 广播地址
  static const String broadcastAddress = '255.255.255.255';
  
  /// 发现服务器的回调
  Function(DiscoveredServer server)? onServerDiscovered;
  
  /// 扫描完成的回调
  Function(List<DiscoveredServer> servers)? onScanComplete;
  
  /// 错误回调
  Function(String error)? onError;

  /// 获取发现的服务器列表
  List<DiscoveredServer> get discoveredServers => List.unmodifiable(_discoveredServers);
  
  /// 是否正在扫描
  bool get isScanning => _isScanning;

  /// 开始扫描局域网内的服务器
  /// [timeout] 扫描超时时间，默认3秒
  /// [retryCount] 重试次数，默认3次
  Future<List<DiscoveredServer>> startDiscovery({
    Duration timeout = const Duration(seconds: 3),
    int retryCount = 3,
  }) async {
    if (_isScanning) {
      DebugUtils.log('UDP发现服务正在扫描中...', name: 'socket');
      return _discoveredServers;
    }

    _isScanning = true;
    _discoveredServers.clear();

    Timer? timeoutTimer;
    try {
      // 创建UDP Socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _discoveryDoneCompleter = Completer<void>();
      _localIpv4Prefixes = await _computeLocalIpv4CClassPrefixes();
      
      DebugUtils.log('UDP发现服务已启动，本地端口: ${_socket!.port}', name: 'socket');
      
      // 监听响应
      _socket!.listen(
        _onDataReceived,
        onError: (error) {
          DebugUtils.log('UDP接收错误: $error', name: 'socket');
          onError?.call('UDP接收错误: $error');
        },
      );

      timeoutTimer = Timer(timeout, () {
        if (!(_discoveryDoneCompleter?.isCompleted ?? true)) {
          _discoveryDoneCompleter?.complete();
        }
      });

      await _sendDiscoveryRequestsWithRetry(retryCount: retryCount);

      await _discoveryDoneCompleter!.future;
      
    } catch (e) {
      DebugUtils.log('UDP发现服务错误: $e', name: 'socket');
      onError?.call('UDP发现服务错误: $e');
    } finally {
      timeoutTimer?.cancel();
      _stopDiscovery();
      _discoveryDoneCompleter = null;
    }

    onScanComplete?.call(_discoveredServers);
    return _discoveredServers;
  }

  /// 发送发现请求（带重试），并在满足目标数量时提前结束
  Future<void> _sendDiscoveryRequestsWithRetry({required int retryCount}) async {
    for (int i = 0; i < retryCount; i++) {
      if (!_isScanning || (_discoveryDoneCompleter?.isCompleted ?? true)) {
        return;
      }
      _sendDiscoveryRequest();
      await Future.any([
        Future.delayed(const Duration(milliseconds: 500)),
        _discoveryDoneCompleter!.future,
      ]);
    }
  }

  /// 发送发现请求
  void _sendDiscoveryRequest() {
    if (_socket == null) return;

    try {
      // 构建HeartEcho消息
      final message = MESSAGE()
        ..mSGtype = MSGTYPE.HeartEcho
        ..echoData = (EchoData()
          ..clientEnd = CLIENTEND.Desktop
          ..echomsg = 'discover');

      final data = message.writeToBuffer();
      
      // 发送广播
      final sent = _socket!.send(
        data,
        InternetAddress(broadcastAddress),
        udpEchoPort,
      );
      
      DebugUtils.log('已发送UDP发现请求，字节数: $sent', name: 'socket');
      
      // 同时尝试发送到常见网段
      _sendToCommonSubnets(data);
      
    } catch (e) {
      DebugUtils.log('发送UDP发现请求失败: $e', name: 'socket');
    }
  }

  /// 发送到常见网段
  void _sendToCommonSubnets(List<int> data) {
    // 关键逻辑：只向“本机当前所在局域网网段”发送，避免跨场地扫描到其它网段服务器。
    final prefixes = _localIpv4CClassPrefixes();
    for (final prefix in prefixes) {
      try {
        _socket?.send(
          data,
          InternetAddress('$prefix.255'),
          udpEchoPort,
        );
      } catch (_) {
        // 忽略发送失败
      }
    }
  }

  /// 获取本机当前可用的 IPv4 /24 网段前缀（例如 192.168.101）
  List<String> _localIpv4CClassPrefixes() {
    return _localIpv4Prefixes;
  }

  /// 计算本机当前可用的 IPv4 /24 网段前缀（例如 192.168.101）
  Future<List<String>> _computeLocalIpv4CClassPrefixes() async {
    try {
      final prefixes = <String>{};
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final itf in interfaces) {
        for (final addr in itf.addresses) {
          final ip = addr.address;
          if (!_isPrivateIpv4(ip)) {
            continue;
          }
          final parts = ip.split('.');
          if (parts.length != 4) {
            continue;
          }
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
      return prefixes.toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// 判断某个 IPv4 是否属于私有网段（RFC1918）
  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
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

  /// 判断某个服务器 IP 是否与本机处于同一局域网（按 IPv4 前三段 /24 判断）
  bool _isServerInSameLan(String serverIp) {
    if (!_isPrivateIpv4(serverIp)) {
      return false;
    }
    if (_localIpv4Prefixes.isEmpty) {
      // 关键逻辑：若本机网段获取失败，不应过滤响应；否则会导致 UDP 发现永远为空。
      return true;
    }
    final parts = serverIp.split('.');
    if (parts.length != 4) {
      return false;
    }
    // 关键逻辑：以“本机当前连接网络的前三段前缀”判断同一局域网，避免跨场地误发现。
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    return _localIpv4Prefixes.contains(prefix);
  }

  /// 处理接收到的数据
  void _onDataReceived(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram != null) {
        _processResponse(datagram);
      }
    }
  }

  /// 处理响应数据
  void _processResponse(Datagram datagram) {
    try {
      final message = MESSAGE.fromBuffer(datagram.data);
      
      if (message.mSGtype == MSGTYPE.HeartEcho) {
        final serverIp = datagram.address.address;
        if (!_isServerInSameLan(serverIp)) {
          // 关键逻辑：过滤非本机所在局域网的响应，避免跨网段发现到其它场地服务器。
          return;
        }
        
        // 检查是否已发现
        if (_discoveredServers.any((s) => s.ipAddress == serverIp)) {
          return;
        }

        final server = DiscoveredServer(
          ipAddress: serverIp,
          tcpPort: iPadServerPort,
          serverType: message.hasEchoData() ? message.echoData.clientEnd : CLIENTEND.Desktop,
          discoveredAt: DateTime.now(),
          echoMessage: message.hasEchoData() ? message.echoData.echomsg : null,
        );

        _discoveredServers.add(server);
        DebugUtils.log('发现服务器: $server', name: 'socket');
        onServerDiscovered?.call(server);
        _tryCompleteDiscoveryEarly();
      }
    } catch (e) {
      DebugUtils.log('解析UDP响应失败: $e', name: 'socket');
    }
  }

  /// 若已同时发现墙面与桌面服务器，则提前结束本次扫描
  void _tryCompleteDiscoveryEarly() {
    final hasWall = _discoveredServers.any((s) => s.serverType == CLIENTEND.WALL);
    final hasDesktop = _discoveredServers.any((s) => s.serverType == CLIENTEND.Desktop);
    if (hasWall && hasDesktop && !(_discoveryDoneCompleter?.isCompleted ?? true)) {
      _discoveryDoneCompleter?.complete();
    }
  }

  /// 停止发现
  void _stopDiscovery() {
    _isScanning = false;
    _socket?.close();
    _socket = null;
    DebugUtils.log('UDP发现服务已停止', name: 'socket');
  }

  /// 手动停止扫描
  ///
  /// 说明：
  /// - 通过 complete 让 startDiscovery 内部等待尽快结束
  /// - 再关闭 Socket，释放端口资源
  void stopDiscovery() {
    if (!(_discoveryDoneCompleter?.isCompleted ?? true)) {
      _discoveryDoneCompleter?.complete();
    }
    _stopDiscovery();
  }

  /// 清空发现的服务器列表
  void clearDiscoveredServers() {
    _discoveredServers.clear();
  }

  /// 释放资源
  void dispose() {
    _stopDiscovery();
    _discoveredServers.clear();
  }
}

