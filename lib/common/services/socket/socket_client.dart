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
  
  /// 最大重连次数
  final int maxReconnectAttempts = 5;
  
  /// 重连间隔（秒）
  final int reconnectInterval = 3;
  
  /// 心跳间隔（秒）
  final int heartbeatInterval = 5;
  
  /// 是否主动断开
  bool _isManualDisconnect = false;
  
  /// 是否允许自动重连（用于区分“启动阶段轻量恢复”和“业务强关联下的持续重连”）
  bool _autoReconnectEnabled = true;

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
  Future<bool> connect(String host, int port, {bool autoReconnect = true}) async {
    if (isConnected) {
      final bool sameEndpoint = _host == host && _port == port;
      if (sameEndpoint) {
        DebugUtils.log('Socket已经连接', name: 'socket');
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
    
    return await _doConnect();
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
  Future<bool> _doConnect() async {
    try {
      _updateState(SocketState.connecting);
      DebugUtils.log('正在连接到服务器 $_host:$_port...', name: 'socket');

      _socket = await Socket.connect(
        _host!,
        _port!,
        timeout: Duration(milliseconds: MessageConstants.timeOut),
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
      DebugUtils.log('Socket连接失败: $e', name: 'socket');
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
      DebugUtils.log('❌ Socket未连接，无法发送消息', name: 'socket');
      DebugUtils.log('   当前状态: $_state', name: 'socket');
      DebugUtils.log('   目标地址: $_host:$_port', name: 'socket');
      onError?.call('Socket未连接');
      return;
    }

    try {
      // 心跳消息不输出日志
      final isHeartbeat = message.mSGtype == MSGTYPE.HeartEcho;
      
      if (!isHeartbeat) {
        // 打印消息详情（非心跳消息）
        DebugUtils.log('======== 发送消息 ========', name: 'socket');
        DebugUtils.log('目标服务器: $_host:$_port', name: 'socket');
        DebugUtils.log('消息类型: ${message.mSGtype}', name: 'socket');
        
        if (message.hasServerMessage()) {
          final sm = message.serverMessage;
          DebugUtils.log('ServerMessage:', name: 'socket');
          DebugUtils.log('  - serverBehaviour: ${sm.serverBehaviour}', name: 'socket');
          DebugUtils.log('  - gameName: "${sm.gameName}"', name: 'socket');
          DebugUtils.log('  - on: ${sm.on}', name: 'socket');
          if (sm.hasVolumeValue()) {
            DebugUtils.log('  - volumeValue: ${sm.volumeValue}', name: 'socket');
          }
        }
        
        if (message.hasUnityMessage()) {
          final um = message.unityMessage;
          DebugUtils.log('UnityMessage:', name: 'socket');
          DebugUtils.log('  - unityMSGtype: ${um.unityMSGtype}', name: 'socket');
          if (um.hasOperation()) {
            DebugUtils.log('  - operation: ${um.operation}', name: 'socket');
          }
        }
      }
      
      final bytes = MessageParser.encodeMessage(message);
      
      if (!isHeartbeat) {
        DebugUtils.log('编码后字节数: ${bytes.length}', name: 'socket');
        DebugUtils.log(
          '消息头: ${bytes.sublist(0, 13).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          name: 'socket',
        );
      }
      
      _sendBuffer.add(bytes);
      _processSendBuffer(silent: isHeartbeat);
      
      if (!isHeartbeat) {
        DebugUtils.log('✅ 消息已发送', name: 'socket');
        DebugUtils.log('==========================', name: 'socket');
      }
    } catch (e) {
      DebugUtils.log('❌ 发送消息失败: $e', name: 'socket');
      onError?.call('发送消息失败: $e');
    }
  }

  /// 处理发送缓冲
  /// [silent] 为 true 时不输出日志（用于心跳等频繁消息）
  /// 
  /// 说明：
  /// - 将待发送字节队列依次写入 Socket
  /// - 写入后调用 `flush()`，尽量让数据及时进入系统网络栈
  void _processSendBuffer({bool silent = false}) {
    if (_sendBuffer.isEmpty || !isConnected) {
      return;
    }

    try {
      while (_sendBuffer.isNotEmpty) {
        final bytes = _sendBuffer.removeAt(0);
        _socket?.add(bytes);
        
        if (!silent) {
          // DebugUtils.log('📤 数据已写入Socket，字节数: ${bytes.length}', name: 'socket');
          // 打印完整的十六进制数据（用于调试）
          if (bytes.length < 200) {
            // DebugUtils.log(
            //   '   HEX: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
            //   name: 'socket',
            // );
          }
        }
      }
      
      // 强制刷新 Socket 缓冲区，确保数据立即发送
      final socket = _socket;
      if (socket != null) {
        // 检查 Socket 状态
        if (!silent) {
          DebugUtils.log('📡 Socket状态检查:', name: 'socket');
          DebugUtils.log('   - remoteAddress: ${socket.remoteAddress.address}', name: 'socket');
          DebugUtils.log('   - remotePort: ${socket.remotePort}', name: 'socket');
          DebugUtils.log('   - done: 正在刷新...', name: 'socket');
        }
        
        socket.flush().then((_) {
          if (!silent) {
            // DebugUtils.log('📤 Socket缓冲区已刷新，数据已发送到网络', name: 'socket');
          }
        }).catchError((e) {
          DebugUtils.log('❌ 刷新Socket缓冲区失败: $e', name: 'socket');
          DebugUtils.log('   可能连接已断开', name: 'socket');
        });
      } else {
        DebugUtils.log('❌ Socket 为 null，无法发送', name: 'socket');
      }
      
    } catch (e) {
      DebugUtils.log('❌ 发送数据出错: $e', name: 'socket');
      onError?.call('发送数据出错: $e');
    }
  }

  /// 数据接收回调
  void _onDataReceived(Uint8List data) {
    try {
      _receiveBuffer.addAll(data);
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
          DebugUtils.log('解析消息头失败', name: 'socket');
          _receiveBuffer.clear();
          break;
        }

        // 验证魔术头
        if (head.header != MessageConstants.header) {
          DebugUtils.log('无效的消息头: ${head.header}', name: 'socket');
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
          DebugUtils.log('收到消息，类型: ${message.mSGtype}', name: 'socket');
          onMessageReceived?.call(message);
        } else {
          DebugUtils.log('解析消息数据失败', name: 'socket');
        }
      } catch (e) {
        DebugUtils.log('处理消息出错: $e', name: 'socket');
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
    if (_reconnectAttempts >= maxReconnectAttempts) {
      DebugUtils.log('已达到最大重连次数，停止重连', name: 'socket');
      onError?.call('无法连接到服务器');
      return;
    }

    _reconnectAttempts++;
    DebugUtils.log('将在$reconnectInterval秒后进行第$_reconnectAttempts次重连...', name: 'socket');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: reconnectInterval), () {
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
      DebugUtils.log('Socket状态变更: $newState', name: 'socket');
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

