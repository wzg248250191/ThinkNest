import 'package:think_nest/common/proto/Common.pb.dart';

/// 发现的服务器信息
class DiscoveredServer {
  /// 服务器IP地址
  final String ipAddress;

  /// 服务器端口（TCP端口，用于Socket连接）
  final int tcpPort;

  /// 服务器类型（WALL或Desktop）
  final CLIENTEND serverType;

  /// 发现时间
  final DateTime discoveredAt;

  /// Echo消息
  final String? echoMessage;

  DiscoveredServer({
    required this.ipAddress,
    required this.tcpPort,
    required this.serverType,
    required this.discoveredAt,
    this.echoMessage,
  });

  @override
  String toString() {
    return 'DiscoveredServer(ip: $ipAddress, port: $tcpPort, type: $serverType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredServer &&
        other.ipAddress == ipAddress &&
        other.tcpPort == tcpPort &&
        other.serverType == serverType;
  }

  @override
  int get hashCode => Object.hash(ipAddress, tcpPort, serverType);
}
