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
    // 常见的局域网网段
    final subnets = ['192.168.1', '192.168.0', '192.168.2', '10.0.0', '172.16.0'];
    
    for (final subnet in subnets) {
      try {
        // 发送到广播地址
        _socket?.send(
          data,
          InternetAddress('$subnet.255'),
          udpEchoPort,
        );
      } catch (e) {
        // 忽略发送失败
      }
    }
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

