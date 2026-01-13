import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../index.dart';

/// Socket连接状态
enum SocketState {
  /// 未连接
  disconnected,
  
  /// 连接中
  connecting,
  
  /// 已连接
  connected,
  
  /// 连接失败
  failed,
}

/// Socket客户端
class SocketClient {
  /// 创建 Socket 客户端并配置自动重连策略
  SocketClient({this.maxReconnectAttempts = 20});

  /// Socket实例
  Socket? _socket;
  
  /// 当前连接状态
  SocketState _state = SocketState.disconnected;
  
  /// 服务器地址
  String? _host;
  
  /// 服务器端口
  int? _port;
  
  /// 发送缓冲队列
  final List<Uint8List> _sendBuffer = [];

  bool _isDrainingSendBuffer = false;

  /// 接收数据缓冲
  final List<int> _receiveBuffer = [];
  
  /// 消息接收回调
  Function(MESSAGE message)? onMessageReceived;
  
  /// 连接状态变化回调
  Function(SocketState state)? onStateChanged;
  
  /// 错误回调
  Function(String error)? onError;
  
  /// 心跳定时器
  Timer? _heartbeatTimer;
  
  /// 重连定时器
  Timer? _reconnectTimer;
  
  /// 重连尝试次数
  int _reconnectAttempts = 0;
  
  /// 最大重连次数（null 表示不设上限）
  ///
  /// 说明：
  /// - 默认设置为 20：避免断线后后台长期重连造成耗电/耗网/刷日志
  /// - 如需“始终在线”场景，可在创建 client 时传 null
  final int? maxReconnectAttempts;
  
  /// 重连间隔（秒）
  final int reconnectInterval = 3;
  
  /// 心跳间隔（秒）
  final int heartbeatInterval = 5;
  
  /// 是否主动断开
  bool _isManualDisconnect = false;
  
  /// 是否允许自动重连（用于区分“启动阶段轻量恢复”和“业务强关联下的持续重连”）
  bool _autoReconnectEnabled = true;

  /// 防止异步调度重连时出现“旧任务覆盖新任务”的竞态
  int _reconnectScheduleToken = 0;

  /// 获取当前连接状态
  SocketState get state => _state;
  
  /// 是否已连接
  bool get isConnected => _state == SocketState.connected && _socket != null;

  /// 连接到服务器
  /// 
  /// 说明：
  /// - 建立 TCP 长连接用于发送/接收封包后的 protobuf `MESSAGE`
  /// - 连接成功后会启动心跳，避免长时间空闲被系统/路由器断开
  /// - [autoReconnect] 为 false 时：连接失败/断开不会触发自动重连（适合启动阶段尝试）
  Future<bool> connect(
    String host,
    int port, {
    bool autoReconnect = true,
    Duration? timeout,
  }) async {
    if (isConnected) {
      final bool sameEndpoint = _host == host && _port == port;
      if (sameEndpoint) {
        return true;
      }
      disconnect();
    } else if (_state == SocketState.connecting) {
      final bool sameEndpoint = _host == host && _port == port;
      if (!sameEndpoint) {
        disconnect();
      }
    }

    _host = host;
    _port = port;
    _isManualDisconnect = false;
    // 启动阶段可关闭自动重连，避免网络未就绪时无意义的持续重试
    _autoReconnectEnabled = autoReconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    
    return await _doConnect(timeout: timeout);
  }

  /// 使用上次记录的 host/port 立即发起一次 TCP 重连
  ///
  /// 说明：
  /// - 仅做一次连接尝试，不触发自动重连（由调用方决定是否持续重试）
  /// - 若没有历史 endpoint（从未连接过）会直接返回 false
  Future<bool> reconnect({Duration? timeout}) async {
    if (isConnected) {
      return true;
    }
    final String? host = _host;
    final int? port = _port;
    if (host == null || port == null) {
      return false;
    }
    if (_state == SocketState.connecting) {
      return false;
    }
    _isManualDisconnect = false;
    // 关键逻辑：仅做一次重连尝试，避免在业务侧未要求时后台无限重连造成耗电/耗网。
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    return await _doConnect(timeout: timeout);
  }

  /// 动态切换自动重连开关（通常用于：启动连接成功后再启用持续重连）
  void setAutoReconnectEnabled(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  /// 执行连接
  /// 
  /// 说明：
  /// - 负责真正的 Socket.connect 与数据监听注册
  /// - 连接失败时会按重连策略自动重试（非主动断开情况下）
  Future<bool> _doConnect({Duration? timeout}) async {
    try {
      _updateState(SocketState.connecting);     
      _socket = await Socket.connect(
        _host!,
        _port!,
        timeout: timeout ?? Duration(milliseconds: MessageConstants.timeOut),
      );

      DebugUtils.log('Socket连接成功: ${_socket?.remoteAddress.address}:${_socket?.remotePort}', name: 'socket');
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      // 监听数据接收
      _socket!.listen(
        _onDataReceived,
        onError: _onSocketError,
        onDone: _onSocketClosed,
        cancelOnError: false,
      );

      _updateState(SocketState.connected);
      _reconnectAttempts = 0;
      
      // 启动心跳
      _startHeartbeat();
      
      return true;
    } catch (e) {
     // DebugUtils.log('Socket连接失败: $e', name: 'socket');
      _updateState(SocketState.failed);
      onError?.call('连接失败: $e');
      
      // 尝试重连
      if (!_isManualDisconnect && _autoReconnectEnabled) {
        _scheduleReconnect();
      }
      
      return false;
    }
  }

  /// 发送MESSAGE消息
  /// 
  /// 说明：
  /// - 业务侧传入 protobuf `MESSAGE`，此处会按 `MessageParser.encodeMessage` 封包成 TCP 字节流
  /// - 发送前会进行连接状态校验，避免写入已断开的 Socket
  void sendMessage(MESSAGE message) {
    if (!isConnected) {
      onError?.call('Socket未连接');
      return;
    }

    try {
      final bytes = MessageParser.encodeMessage(message);
      _sendBuffer.add(bytes);
      // 关键逻辑：发送缓冲采用单通道 drain，避免并发写导致 Socket 状态异常。
      _processSendBuffer();
    } catch (e) {
      DebugUtils.log('发送消息错误: $e', name: 'socket');
      onError?.call('发送消息失败: $e');
    }
  }

  /// 处理发送缓冲
  /// 
  /// 说明：
  /// - 将待发送字节队列依次写入 Socket
  /// - 写入后调用 `flush()`，尽量让数据及时进入系统网络栈
  void _processSendBuffer() {
    if (_sendBuffer.isEmpty || !isConnected) {
      return;
    }

    if (_isDrainingSendBuffer) {
      return;
    }
    _isDrainingSendBuffer = true;
    unawaited(_drainSendBuffer());
  }

  /// 串行写入并 flush 发送缓冲，避免并发写导致 StreamSink 状态异常。
  Future<void> _drainSendBuffer() async {
    try {
      while (isConnected) {
        final socket = _socket;
        if (socket == null) {
          return;
        }

        while (_sendBuffer.isNotEmpty) {
          final bytes = _sendBuffer.removeAt(0);
          socket.add(bytes);
        }

        await socket.flush();
        if (_sendBuffer.isEmpty) {
          return;
        }
      }
    } catch (e) {
      DebugUtils.log('发送数据错误: $e', name: 'socket');
      onError?.call('发送数据出错: $e');
      _handleDisconnect();
    } finally {
      _isDrainingSendBuffer = false;
      if (_sendBuffer.isNotEmpty && isConnected) {
        _processSendBuffer();
      }
    }
  }

  /// 数据接收回调
  void _onDataReceived(Uint8List data) {
    try {
      _receiveBuffer.addAll(data);
      if (_receiveBuffer.length > MessageConstants.bufferMaxSize) {
        onError?.call('接收缓冲区溢出，已重置连接');
        _handleDisconnect();
        return;
      }
      _processReceiveBuffer();
    } catch (e) {
      DebugUtils.log('处理接收数据出错: $e', name: 'socket');
      onError?.call('处理接收数据出错: $e');
    }
  }

  /// 处理接收缓冲
  /// 
  /// 说明：
  /// - 处理粘包：可能一次收到多包，也可能只收到半包
  /// - 本项目 Length 字段遵循服务端规则：`整包长度 = head.length + 6`
  /// - 拆出整包后交给 `MessageParser.unParse`，再反序列化为 protobuf `MESSAGE`
  void _processReceiveBuffer() {
    while (_receiveBuffer.length >= MessageConstants.headerLength) {
      try {
        // 读取消息头
        final headerBytes = Uint8List.fromList(
          _receiveBuffer.sublist(0, MessageConstants.headerLength),
        );
        
        final head = MessageParser.unParseHead(headerBytes);
        if (head == null) {
          DebugUtils.log('解析消息头错误', name: 'socket');
          _receiveBuffer.clear();
          break;
        }

        // 验证魔术头
        if (head.header != MessageConstants.header) {
          DebugUtils.log('无效消息头错误: ${head.header}', name: 'socket');
          _receiveBuffer.clear();
          break;
        }

        // 计算完整消息长度（头部 + 消息体长度）
        final totalLength = head.length + 6;
        
        // 检查是否接收完整消息
        if (_receiveBuffer.length < totalLength) {
          // 数据不完整，等待更多数据
          break;
        }

        // 提取完整消息
        final messageBytes = Uint8List.fromList(
          _receiveBuffer.sublist(0, totalLength),
        );
        
        // 从缓冲区移除已处理的数据
        _receiveBuffer.removeRange(0, totalLength);

        // 解析消息
        final messageData = MessageParser.unParse(messageBytes);
        if (messageData != null) {
          // 解析protobuf消息
          final message = MESSAGE.fromBuffer(messageData.body.buffBytes);
          onMessageReceived?.call(message);
        } else {
          DebugUtils.log('解析消息数据错误', name: 'socket');
        }
      } catch (e) {
        DebugUtils.log('处理消息错误: $e', name: 'socket');
        _receiveBuffer.clear();
        break;
      }
    }
  }

  /// Socket错误回调
  void _onSocketError(error) {
    DebugUtils.log('Socket错误: $error', name: 'socket');
    onError?.call('Socket错误: $error');
    _handleDisconnect();
  }

  /// Socket关闭回调
  void _onSocketClosed() {
    DebugUtils.log('Socket连接已关闭', name: 'socket');
    _handleDisconnect();
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _stopHeartbeat();
    _updateState(SocketState.disconnected);
    _socket = null;
    _sendBuffer.clear();
    // 关键逻辑：断线时重置发送 drain 状态，避免“旧 drain”持续占用导致后续无法发送。
    _isDrainingSendBuffer = false;
    _receiveBuffer.clear();

    // 如果不是主动断开，则尝试重连
    if (!_isManualDisconnect && _autoReconnectEnabled) {
      _scheduleReconnect();
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (!_autoReconnectEnabled) {
      return;
    }

    // 关键逻辑：重连调度涉及获取本机网段（异步），这里通过 token 避免并发调度导致定时器状态错乱。
    final int token = ++_reconnectScheduleToken;
    unawaited(_scheduleReconnectInternal(token));
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

  /// 尝试判断“当前网络环境下是否仍可能与目标 host 处于同一局域网”
  ///
  /// 返回：
  /// - true：同一局域网（按 IPv4 前三段 /24 判断）
  /// - false：已明确不在同一局域网
  /// - null：无法判断（例如暂时取不到本机网卡/无私网 IPv4），不应据此关闭重连
  Future<bool?> _isHostInSameLanMaybe(String host) async {
    if (!_isPrivateIpv4(host)) {
      return null;
    }
    final hostParts = host.split('.');
    if (hostParts.length != 4) {
      return null;
    }
    final hostPrefix = '${hostParts[0]}.${hostParts[1]}.${hostParts[2]}';
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final prefixes = <String>{};
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
      if (prefixes.isEmpty) {
        return null;
      }
      return prefixes.contains(hostPrefix);
    } catch (_) {
      return null;
    }
  }

  /// 执行“可取消”的异步重连调度
  Future<void> _scheduleReconnectInternal(int token) async {
    if (!_autoReconnectEnabled || token != _reconnectScheduleToken) {
      return;
    }
    final String? host = _host;
    final int? port = _port;
    if (host == null || port == null) {
      return;
    }

    final bool? sameLan = await _isHostInSameLanMaybe(host);
    if (!_autoReconnectEnabled || token != _reconnectScheduleToken) {
      return;
    }
    if (sameLan == false) {
      // 关键逻辑：检测到已切换到不同局域网时，停止对旧 IP 的自动重连，避免后台持续重连造成耗电/耗网。
      DebugUtils.log('检测到网络已切换，停止自动重连: $host:$port', name: 'socket');
      _autoReconnectEnabled = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      return;
    }

    _reconnectAttempts++;
    if (maxReconnectAttempts != null && _reconnectAttempts >= maxReconnectAttempts!) {
      // 关键逻辑：达到上限后关闭自动重连，避免断线回调重复触发重连调度导致持续刷日志。
      DebugUtils.log('已达到最大重连次数，停止重连', name: 'socket');
      _autoReconnectEnabled = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      onError?.call('无法连接到服务器');
      return;
    }

    // 关键逻辑：PC 服务器可能在系统自启动阶段较晚可用，采用指数退避持续重试，避免固定次数后放弃导致“永远连不上”。
    final int backoffFactor = 1 << ((_reconnectAttempts - 1).clamp(0, 4));
    final int nextIntervalSeconds = (reconnectInterval * backoffFactor).clamp(3, 30);
    DebugUtils.log('将在$nextIntervalSeconds秒后进行第$_reconnectAttempts次重连...', name: 'socket');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: nextIntervalSeconds), () {
      // Timer 触发时可能已经连上/或被禁用重连，直接忽略即可
      if (_state == SocketState.connected || _socket != null || !_autoReconnectEnabled) {
        return;
      }
      DebugUtils.log('开始第$_reconnectAttempts次重连...', name: 'socket');
      _doConnect();
    });
  }

  /// 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: heartbeatInterval),
      (timer) {
        if (isConnected) {
          _sendHeartbeat();
        }
      },
    );
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 发送心跳消息
  /// 
  /// 说明：
  /// - 定期发送 `MSGTYPE.HeartEcho`，用于维持长连接与探活
  /// - 心跳包使用相同的封包规则（头+Length+cmd）
  void _sendHeartbeat() {
    final heartbeat = MESSAGE()
      ..mSGtype = MSGTYPE.HeartEcho
      ..echoData = (EchoData()..clientEnd = CLIENTEND.Desktop);
    
    sendMessage(heartbeat);
  }

  /// 更新连接状态
  void _updateState(SocketState newState) {
    if (_state != newState) {
      _state = newState;
      //DebugUtils.log('Socket状态变更: $newState', name: 'socket');
      onStateChanged?.call(newState);
    }
  }

  /// 断开连接
  void disconnect() {
    DebugUtils.log('主动断开Socket连接', name: 'socket');
    _isManualDisconnect = true;
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    
    try {
      _socket?.close();
    } catch (e) {
      DebugUtils.log('关闭Socket出错: $e', name: 'socket');
    }
    
    _socket = null;
    _sendBuffer.clear();
    _receiveBuffer.clear();
    _updateState(SocketState.disconnected);
  }

  /// 销毁客户端
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
  }
}

