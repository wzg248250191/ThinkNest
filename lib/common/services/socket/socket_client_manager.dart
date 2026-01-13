import 'dart:async';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'socket_client.dart';
import 'server_type.dart';

/// Socket客户端管理器
/// 管理多个Socket客户端连接（墙面服务器和桌面服务器）
class SocketClientManager {
  /// 墙面服务器客户端
  late SocketClient _wallClient;
  
  /// 桌面服务器客户端
  late SocketClient _desktopClient;
  
  /// 墙面服务器IP
  String? _wallServerIp;
  
  /// 桌面服务器IP
  String? _desktopServerIp;
  
  /// 消息回调（按服务器类型分发）
  Function(ServerType serverType, MESSAGE message)? onMessageReceived;
  
  /// 状态变化回调（按服务器类型分发）
  Function(ServerType serverType, SocketState state)? onStateChanged;
  
  /// 错误回调
  Function(ServerType serverType, String error)? onError;

  SocketClientManager() {
    _initClients();
  }

  /// 初始化客户端
  void _initClients() {
    _wallClient = SocketClient();
    _desktopClient = SocketClient();
    
    // 设置墙面服务器回调
    _wallClient.onMessageReceived = (message) {
      onMessageReceived?.call(ServerType.wall, message);
    };
    _wallClient.onStateChanged = (state) {
      onStateChanged?.call(ServerType.wall, state);
    };
    _wallClient.onError = (error) {
      onError?.call(ServerType.wall, error);
    };
    
    // 设置桌面服务器回调
    _desktopClient.onMessageReceived = (message) {
      onMessageReceived?.call(ServerType.desktop, message);
    };
    _desktopClient.onStateChanged = (state) {
      onStateChanged?.call(ServerType.desktop, state);
    };
    _desktopClient.onError = (error) {
      onError?.call(ServerType.desktop, error);
    };
  }

  /// 获取墙面服务器连接状态
  SocketState get wallState => _wallClient.state;
  
  /// 获取桌面服务器连接状态
  SocketState get desktopState => _desktopClient.state;
  
  /// 墙面服务器是否已连接
  bool get isWallConnected => _wallClient.isConnected;
  
  /// 桌面服务器是否已连接
  bool get isDesktopConnected => _desktopClient.isConnected;
  
  /// 是否有任一服务器连接
  bool get isAnyConnected => isWallConnected || isDesktopConnected;
  
  /// 是否两个服务器都已连接
  bool get isAllConnected => isWallConnected && isDesktopConnected;
  
  /// 获取墙面服务器IP
  String? get wallServerIp => _wallServerIp;
  
  /// 获取桌面服务器IP
  String? get desktopServerIp => _desktopServerIp;

  /// 连接到墙面服务器
  ///
  /// 说明：
  /// - [autoReconnect] 用于控制底层 SocketClient 是否在断线后自动重连
  /// - 启动阶段通常传 false，连接成功后再由上层手动开启重连
  Future<bool> connectToWall(
    String host,
    int port, {
    bool autoReconnect = true,
    Duration? timeout,
  }) async {
    final success = await _wallClient.connect(host, port, autoReconnect: autoReconnect, timeout: timeout);
    if (success) {
      _wallServerIp = host;
    }
    return success;
  }

  /// 连接到桌面服务器
  ///
  /// 说明同 [connectToWall]
  Future<bool> connectToDesktop(
    String host,
    int port, {
    bool autoReconnect = true,
    Duration? timeout,
  }) async {
    //DebugUtils.log('连接到桌面服务器: $host:$port', name: 'socket');
    final success = await _desktopClient.connect(host, port, autoReconnect: autoReconnect, timeout: timeout);
    if (success) {
      _desktopServerIp = host;
    }
    return success;
  }

  /// 根据服务器类型连接
  ///
  /// 说明：
  /// - 统一入口，便于上层在“墙/桌”两条链路复用相同的连接策略
  Future<bool> connect(
    ServerType serverType,
    String host,
    int port, {
    bool autoReconnect = true,
    Duration? timeout,
  }) async {
    switch (serverType) {
      case ServerType.wall:
        return await connectToWall(host, port, autoReconnect: autoReconnect, timeout: timeout);
      case ServerType.desktop:
        return await connectToDesktop(host, port, autoReconnect: autoReconnect, timeout: timeout);
    }
  }

  /// 使用当前客户端记录的 endpoint 立即发起一次 TCP 重连
  ///
  /// 说明：
  /// - 用于“断开后希望快速恢复”的场景
  /// - 若客户端没有历史 endpoint（从未连接过）会直接返回 false
  Future<bool> reconnect(ServerType serverType, {Duration? timeout}) async {
    return await getClient(serverType).reconnect(timeout: timeout);
  }

  /// 断开墙面服务器
  void disconnectWall() {
    _wallClient.disconnect();
    _wallServerIp = null;
  }

  /// 断开桌面服务器
  void disconnectDesktop() {
    _desktopClient.disconnect();
    _desktopServerIp = null;
  }

  /// 断开指定服务器
  void disconnect(ServerType serverType) {
    switch (serverType) {
      case ServerType.wall:
        disconnectWall();
        break;
      case ServerType.desktop:
        disconnectDesktop();
        break;
    }
  }

  /// 断开所有服务器
  void disconnectAll() {
    disconnectWall();
    disconnectDesktop();
  }

  /// 发送消息到墙面服务器
  void sendToWall(MESSAGE message) {
    if (!isWallConnected) {
      onError?.call(ServerType.wall, '墙面服务器未连接');
      return;
    }
    _wallClient.sendMessage(message);
  }

  /// 发送消息到桌面服务器
  void sendToDesktop(MESSAGE message) {
    if (!isDesktopConnected) {
      onError?.call(ServerType.desktop, '桌面服务器未连接');
      return;
    }
    _desktopClient.sendMessage(message);
  }

  /// 发送消息到指定服务器
  void sendTo(ServerType serverType, MESSAGE message) {
    switch (serverType) {
      case ServerType.wall:
        sendToWall(message);
        break;
      case ServerType.desktop:
        sendToDesktop(message);
        break;
    }
  }

  /// 发送消息到所有已连接的服务器
  void sendToAll(MESSAGE message) {
    if (isWallConnected) {
      sendToWall(message);
    }
    if (isDesktopConnected) {
      sendToDesktop(message);
    }
  }

  /// 获取客户端
  SocketClient getClient(ServerType serverType) {
    switch (serverType) {
      case ServerType.wall:
        return _wallClient;
      case ServerType.desktop:
        return _desktopClient;
    }
  }

  /// 动态切换指定服务端的自动重连开关
  void setAutoReconnectEnabled(ServerType serverType, bool enabled) {
    getClient(serverType).setAutoReconnectEnabled(enabled);
  }

  /// 释放资源
  void dispose() {
    _wallClient.dispose();
    _desktopClient.dispose();
  }
}

