import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'message_constants.dart';
import 'message_parser.dart';

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

  /// 获取当前连接状态
  SocketState get state => _state;
  
  /// 是否已连接
  bool get isConnected => _state == SocketState.connected && _socket != null;

  /// 连接到服务器
  /// 
  /// 说明：
  /// - 建立 TCP 长连接用于发送/接收封包后的 protobuf `MESSAGE`
  /// - 连接成功后会启动心跳，避免长时间空闲被系统/路由器断开
  Future<bool> connect(String host, int port) async {
    if (_state == SocketState.connected) {
      print('Socket已经连接');
      return true;
    }

    _host = host;
    _port = port;
    _isManualDisconnect = false;
    
    return await _doConnect();
  }

  /// 执行连接
  /// 
  /// 说明：
  /// - 负责真正的 Socket.connect 与数据监听注册
  /// - 连接失败时会按重连策略自动重试（非主动断开情况下）
  Future<bool> _doConnect() async {
    try {
      _updateState(SocketState.connecting);
      print('正在连接到服务器 $_host:$_port...');

      _socket = await Socket.connect(
        _host!,
        _port!,
        timeout: Duration(milliseconds: MessageConstants.timeOut),
      );

      print('Socket连接成功: ${_socket?.remoteAddress.address}:${_socket?.remotePort}');
      
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
      print('Socket连接失败: $e');
      _updateState(SocketState.failed);
      onError?.call('连接失败: $e');
      
      // 尝试重连
      if (!_isManualDisconnect) {
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
      print('❌ Socket未连接，无法发送消息');
      print('   当前状态: $_state');
      print('   目标地址: $_host:$_port');
      onError?.call('Socket未连接');
      return;
    }

    try {
      // 心跳消息不输出日志
      final isHeartbeat = message.mSGtype == MSGTYPE.HeartEcho;
      
      if (!isHeartbeat) {
        // 打印消息详情（非心跳消息）
        print('======== 发送消息 ========');
        print('目标服务器: $_host:$_port');
        print('消息类型: ${message.mSGtype}');
        
        if (message.hasServerMessage()) {
          final sm = message.serverMessage;
          print('ServerMessage:');
          print('  - serverBehaviour: ${sm.serverBehaviour}');
          print('  - gameName: "${sm.gameName}"');
          print('  - on: ${sm.on}');
          if (sm.hasVolumeValue()) {
            print('  - volumeValue: ${sm.volumeValue}');
          }
        }
        
        if (message.hasUnityMessage()) {
          final um = message.unityMessage;
          print('UnityMessage:');
          print('  - unityMSGtype: ${um.unityMSGtype}');
          if (um.hasOperation()) {
            print('  - operation: ${um.operation}');
          }
        }
      }
      
      final bytes = MessageParser.encodeMessage(message);
      
      if (!isHeartbeat) {
        print('编码后字节数: ${bytes.length}');
        print('消息头: ${bytes.sublist(0, 13).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      }
      
      _sendBuffer.add(bytes);
      _processSendBuffer(silent: isHeartbeat);
      
      if (!isHeartbeat) {
        print('✅ 消息已发送');
        print('==========================');
      }
    } catch (e) {
      print('❌ 发送消息失败: $e');
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
          print('📤 数据已写入Socket，字节数: ${bytes.length}');
          // 打印完整的十六进制数据（用于调试）
          if (bytes.length < 200) {
            print('   HEX: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          }
        }
      }
      
      // 强制刷新 Socket 缓冲区，确保数据立即发送
      final socket = _socket;
      if (socket != null) {
        // 检查 Socket 状态
        if (!silent) {
          print('📡 Socket状态检查:');
          print('   - remoteAddress: ${socket.remoteAddress.address}');
          print('   - remotePort: ${socket.remotePort}');
          print('   - done: 正在刷新...');
        }
        
        socket.flush().then((_) {
          if (!silent) {
            print('📤 Socket缓冲区已刷新，数据已发送到网络');
          }
        }).catchError((e) {
          print('❌ 刷新Socket缓冲区失败: $e');
          print('   可能连接已断开');
        });
      } else {
        print('❌ Socket 为 null，无法发送');
      }
      
    } catch (e) {
      print('❌ 发送数据出错: $e');
      onError?.call('发送数据出错: $e');
    }
  }

  /// 数据接收回调
  void _onDataReceived(Uint8List data) {
    try {
      _receiveBuffer.addAll(data);
      _processReceiveBuffer();
    } catch (e) {
      print('处理接收数据出错: $e');
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
          print('解析消息头失败');
          _receiveBuffer.clear();
          break;
        }

        // 验证魔术头
        if (head.header != MessageConstants.header) {
          print('无效的消息头: ${head.header}');
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
          print('收到消息，类型: ${message.mSGtype}');
          onMessageReceived?.call(message);
        } else {
          print('解析消息数据失败');
        }
      } catch (e) {
        print('处理消息出错: $e');
        _receiveBuffer.clear();
        break;
      }
    }
  }

  /// Socket错误回调
  void _onSocketError(error) {
    print('Socket错误: $error');
    onError?.call('Socket错误: $error');
    _handleDisconnect();
  }

  /// Socket关闭回调
  void _onSocketClosed() {
    print('Socket连接已关闭');
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
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('已达到最大重连次数，停止重连');
      onError?.call('无法连接到服务器');
      return;
    }

    _reconnectAttempts++;
    print('将在$reconnectInterval秒后进行第$_reconnectAttempts次重连...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: reconnectInterval), () {
      print('开始第$_reconnectAttempts次重连...');
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
      print('Socket状态变更: $newState');
      onStateChanged?.call(newState);
    }
  }

  /// 断开连接
  void disconnect() {
    print('主动断开Socket连接');
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    
    try {
      _socket?.close();
    } catch (e) {
      print('关闭Socket出错: $e');
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

