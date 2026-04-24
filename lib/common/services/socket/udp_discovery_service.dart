import 'dart:async';
import 'dart:io';

import '../../index.dart';
import 'lan_ipv4_utils.dart';

/// UDP发现服务
/// 用于自动发现局域网内的PC服务器
class UdpDiscoveryService {
  /// UDP Socket
  RawDatagramSocket? _socket;
  
  /// 发现的服务器列表
  final List<DiscoveredServer> _discoveredServers = [];

  /// 本机当前可用的 IPv4 网段缓存（IP/掩码/网络地址）
  List<LanIpv4Network> _localIpv4Networks = const <LanIpv4Network>[];
  
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
      _localIpv4Networks = await _computeLocalIpv4Networks();
      
      // 监听响应
      _socket!.listen(
        _onDataReceived,
        onError: (error) {
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
      final String msg = e.toString();
      if (msg.contains('Operation not permitted') || msg.contains('operation not permitted')) {
        // 关键逻辑：Release 包在 Android 未声明 INTERNET 时，创建 UDP Socket 会直接被系统拒绝（EPERM），给出明确指引便于定位。
        onError?.call('UDP发现服务错误: 缺少INTERNET权限或系统限制，已为Release补齐权限，请重新安装后重试。原始错误: $e');
      } else {
        onError?.call('UDP发现服务错误: $e');
      }
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
      _socket!.send(
        data,
        InternetAddress(broadcastAddress),
        udpEchoPort,
      );
      
      // 同时尝试发送到常见网段
      _sendToCommonSubnets(data);
      
    } catch (e) {
      // ignore
    }
  }

  /// 发送到常见网段
  void _sendToCommonSubnets(List<int> data) {
    // 关键逻辑：按“本机真实子网掩码”计算广播地址，避免固定 /24 广播导致 /23 等网络发现不全。
    final networks = _localIpv4NetworksOfCurrentDevice();
    for (final network in networks) {
      try {
        _socket?.send(
          data,
          InternetAddress(network.broadcast),
          udpEchoPort,
        );
      } catch (_) {
        // 忽略发送失败
      }
    }
  }

  /// 获取本机当前可用的 IPv4 网段信息
  List<LanIpv4Network> _localIpv4NetworksOfCurrentDevice() {
    return _localIpv4Networks;
  }

  /// 计算本机当前可用的 IPv4 网段信息（IP/掩码/网络地址）
  Future<List<LanIpv4Network>> _computeLocalIpv4Networks() async {
    return LanIpv4Utils.localNetworks();
  }

  /// 判断某个服务器 IP 是否与本机处于同一局域网
  bool _isServerInSameLan(String serverIp) {
    final localNetworks = _localIpv4NetworksOfCurrentDevice();
    if (localNetworks.isEmpty) {
      // 关键逻辑：没有本机网段信息时无法做准确同网段判定，按安全策略过滤该响应。
      return false;
    }
    // 关键逻辑：通过“(服务器IP & 本机掩码) == 本机网络地址”判断同局域网，兼容 /23、/24 等掩码。
    return LanIpv4Utils.isInSameLan(serverIp, localNetworks);
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
          // 关键逻辑：发现阶段只保留“按真实掩码判定为同网段”的服务器，避免跨局域网误发现。
          return;
        }

        final CLIENTEND serverType = message.hasEchoData() ? message.echoData.clientEnd : CLIENTEND.Desktop;
        
        // 检查是否已发现
        if (_discoveredServers.any((s) => s.ipAddress == serverIp && s.serverType == serverType)) {
          return;
        }

        final server = DiscoveredServer(
          ipAddress: serverIp,
          tcpPort: iPadServerPort,
          serverType: serverType,
          discoveredAt: DateTime.now(),
          echoMessage: message.hasEchoData() ? message.echoData.echomsg : null,
        );

        _discoveredServers.add(server);
        onServerDiscovered?.call(server);
        _tryCompleteDiscoveryEarly();
      }
    } catch (e) {
      // ignore
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

