import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../values/constants.dart';

/// 指令通道状态
enum CommandChannelStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// 指令消息模型
class CommandMessage {
  final String id;
  final String type;
  final String? courseId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const CommandMessage({
    required this.id,
    required this.type,
    required this.data,
    this.courseId,
    required this.timestamp,
  });

  /// 将消息序列化为 JSON Map
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'courseId': courseId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 从 JSON Map 反序列化消息
  static CommandMessage fromJson(Map<String, dynamic> json) {
    return CommandMessage(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      courseId: json['courseId'] as String?,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// 负责与服务器建立长连接并收发指令
class CommandChannelService extends GetxService {
  static CommandChannelService get to => Get.find();

  final Rx<CommandChannelStatus> status =
      CommandChannelStatus.disconnected.obs;

  final StreamController<CommandMessage> _inboundController =
      StreamController<CommandMessage>.broadcast();

  Stream<CommandMessage> get inboundStream => _inboundController.stream;

  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Uri _endpoint = Uri.parse(Constants.apiUrl)
      .replace(scheme: 'wss', path: '/ws/command');
  bool _manualClose = false;
  int _reconnectAttempt = 0;

  /// 初始化指令通道服务（可选设置默认连接地址）
  void init({Uri? endpoint}) {
    if (endpoint != null) {
      _endpoint = endpoint;
    }
  }

  /// 获取当前默认连接地址
  Uri get endpoint => _endpoint;

  /// 设置默认连接地址（下次 connect 将使用此地址）
  void setEndpoint(Uri endpoint) {
    _endpoint = endpoint;
  }

  /// 确保已连接（未连接则发起连接）
  Future<void> ensureConnected({Uri? endpoint}) async {
    if (status.value == CommandChannelStatus.connected) {
      return;
    }
    await connect(endpoint: endpoint);
  }

  /// 建立连接
  Future<void> connect({Uri? endpoint}) async {
    final Uri uri = endpoint ?? _endpoint;
    if (status.value == CommandChannelStatus.connecting ||
        status.value == CommandChannelStatus.reconnecting) {
      return;
    }
    if (status.value == CommandChannelStatus.connected && _socket != null) {
      return;
    }

    _manualClose = false;
    status.value = _reconnectAttempt == 0
        ? CommandChannelStatus.connecting
        : CommandChannelStatus.reconnecting;

    try {
      await _disposeSocket();
      final WebSocket socket = await WebSocket.connect(uri.toString());
      _socket = socket;
      _reconnectAttempt = 0;
      status.value = CommandChannelStatus.connected;
      _startHeartbeat();

      _socketSub = socket.listen(
        _handleInbound,
        onError: (_) => _handleSocketClosed(),
        onDone: _handleSocketClosed,
        cancelOnError: true,
      );
    } catch (_) {
      status.value = CommandChannelStatus.disconnected;
      _scheduleReconnect();
    }
  }

  /// 主动断开连接
  Future<void> disconnect() async {
    _manualClose = true;
    status.value = CommandChannelStatus.disconnected;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disposeSocket();
  }

  /// 发送指令
  Future<void> send(CommandMessage message) async {
    if (status.value != CommandChannelStatus.connected || _socket == null) {
      await ensureConnected();
    }
    final WebSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    socket.add(jsonEncode(message.toJson()));
  }

  /// 清理资源
  Future<void> _disposeSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  /// 处理服务器推送消息
  void _handleInbound(dynamic raw) {
    try {
      if (raw is String) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _inboundController.add(CommandMessage.fromJson(decoded));
        }
        return;
      }
      if (raw is Map) {
        _inboundController.add(CommandMessage.fromJson(raw.cast<String, dynamic>()));
      }
    } catch (_) {}
  }

  /// 处理连接关闭/异常
  void _handleSocketClosed() {
    unawaited(_disposeSocket());
    if (_manualClose) {
      status.value = CommandChannelStatus.disconnected;
      return;
    }
    status.value = CommandChannelStatus.disconnected;
    _scheduleReconnect();
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final WebSocket? socket = _socket;
      if (socket == null) {
        return;
      }
      try {
        socket.add(jsonEncode(<String, dynamic>{'type': 'ping'}));
      } catch (_) {}
    });
  }

  /// 按指数退避策略尝试重连
  void _scheduleReconnect() {
    if (_manualClose) {
      return;
    }
    if (_reconnectTimer != null) {
      return;
    }

    final int attempt = (_reconnectAttempt++).clamp(0, 10);
    final int seconds = (1 << attempt).clamp(1, 30);
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      await connect();
    });
  }

  @override
  /// 服务销毁时释放资源
  void onClose() {
    _manualClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    unawaited(_socketSub?.cancel());
    _socketSub = null;
    unawaited(_socket?.close());
    _socket = null;
    unawaited(_inboundController.close());
    super.onClose();
  }
}

