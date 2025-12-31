import '../../index.dart';

/// 服务器类型
enum ServerType {
  /// 墙面服务器
  wall,

  /// 桌面服务器
  desktop,
}

/// 服务器类型扩展
extension ServerTypeExtension on ServerType {
  /// 将业务侧 ServerType 转换为协议侧 CLIENTEND
  CLIENTEND toClientEnd() {
    switch (this) {
      case ServerType.wall:
        return CLIENTEND.WALL;
      case ServerType.desktop:
        return CLIENTEND.Desktop;
    }
  }

  /// 将协议侧 CLIENTEND 转换为业务侧 ServerType
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

  /// 获取用于 UI/日志输出的显示名称
  String get displayName {
    switch (this) {
      case ServerType.wall:
        return '墙面服务器';
      case ServerType.desktop:
        return '桌面服务器';
    }
  }
}

