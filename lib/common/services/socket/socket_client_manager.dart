// ignore_for_file: avoid_print

import 'dart:async';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'socket_client.dart';

/// 服务器类型
enum ServerType {
  /// 墙面服务器
  wall,
  
  /// 桌面服务器
  desktop,
}

/// 服务器类型扩展
extension ServerTypeExtension on ServerType {
  /// 转换为CLIENTEND
  CLIENTEND toClientEnd() {
    switch (this) {
      case ServerType.wall:
        return CLIENTEND.WALL;
      case ServerType.desktop:
        return CLIENTEND.Desktop;
    }
  }
  
  /// 从CLIENTEND转换
  static ServerType fromClientEnd(CLIENTEND clientEnd) {
    switch (clientEnd) {
      case CLIENTEND.WALL:
        return ServerType.wall;
      case CLIENTEND.Desktop:
        return ServerType.desktop;
      default:
        return ServerType.desktop;
    }
  }
  
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case ServerType.wall:
        return '墙面服务器';
      case ServerType.desktop:
        return '桌面服务器';
    }
  }
}

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
  
  /// 墙面服务器消息回调
  Function(MESSAGE message)? onWallMessageReceived;
  
  /// 桌面服务器消息回调
  Function(MESSAGE message)? onDesktopMessageReceived;
  
  /// 墙面服务器状态变化回调
  Function(SocketState state)? onWallStateChanged;
  
  /// 桌面服务器状态变化回调
  Function(SocketState state)? onDesktopStateChanged;
  
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
      onWallMessageReceived?.call(message);
    };
    _wallClient.onStateChanged = (state) {
      onWallStateChanged?.call(state);
    };
    _wallClient.onError = (error) {
      onError?.call(ServerType.wall, error);
    };
    
    // 设置桌面服务器回调
    _desktopClient.onMessageReceived = (message) {
      onDesktopMessageReceived?.call(message);
    };
    _desktopClient.onStateChanged = (state) {
      onDesktopStateChanged?.call(state);
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
  Future<bool> connectToWall(String host, int port) async {
    print('连接到墙面服务器: $host:$port');
    final success = await _wallClient.connect(host, port);
    if (success) {
      _wallServerIp = host;
    }
    return success;
  }

  /// 连接到桌面服务器
  Future<bool> connectToDesktop(String host, int port) async {
    print('连接到桌面服务器: $host:$port');
    final success = await _desktopClient.connect(host, port);
    if (success) {
      _desktopServerIp = host;
    }
    return success;
  }

  /// 根据服务器类型连接
  Future<bool> connect(ServerType serverType, String host, int port) async {
    switch (serverType) {
      case ServerType.wall:
        return await connectToWall(host, port);
      case ServerType.desktop:
        return await connectToDesktop(host, port);
    }
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
      print('墙面服务器未连接，无法发送消息');
      onError?.call(ServerType.wall, '墙面服务器未连接');
      return;
    }
    _wallClient.sendMessage(message);
  }

  /// 发送消息到桌面服务器
  void sendToDesktop(MESSAGE message) {
    if (!isDesktopConnected) {
      print('桌面服务器未连接，无法发送消息');
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

  /// 释放资源
  void dispose() {
    _wallClient.dispose();
    _desktopClient.dispose();
  }
}

