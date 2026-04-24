// ignore_for_file: unnecessary_string_interpolations

/// Socket 通信服务的主入口文件（单一 library）。
///
/// 该文件本身只承载“公共骨架”，并通过 part 组合多个 mixin，形成最终对外的 [SocketService]：
/// - 公共状态：服务器连接状态、已发现服务器列表、课程清单状态、消息流聚合等
/// - 公共资源：SocketClientManager / UdpDiscoveryService（由连接 mixin 初始化，基类统一回收）
/// - 公共工具：按 [ServerType] 获取 endpoint 状态容器
///
/// 业务能力被拆分到不同的 mixin 文件中：
/// - 连接/发现/恢复：socket_service_connection_mixin.dart
/// - 发送：socket_service_send_mixin.dart
/// - 消息处理：socket_service_handle_mixin.dart
library socket_service;
import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../index.dart';
import 'lan_ipv4_utils.dart';

part 'socket_service_connection_mixin.dart';
part 'socket_service_send_mixin.dart';
part 'socket_service_handle_mixin.dart';

const String _courseListCacheKey = StorageKeys.courseListCache;
const String _lastWallServerIpKey = StorageKeys.lastWallServerIp;
const String _lastWallServerPortKey = StorageKeys.lastWallServerPort;
const String _lastDesktopServerIpKey = StorageKeys.lastDesktopServerIp;
const String _lastDesktopServerPortKey = StorageKeys.lastDesktopServerPort;

class _ServerEndpointState {
  _ServerEndpointState(this.serverType)
      : connectionState = SocketState.disconnected.obs,
        connectedServerIp = RxnString(),
        messageController = StreamController<MESSAGE>.broadcast();

  final ServerType serverType;
  final Rx<SocketState> connectionState;
  final RxnString connectedServerIp;
  final StreamController<MESSAGE> messageController;

  bool hasRequestedCourseListInCurrentConnection = false;
  bool foregroundAutoRecoverEnabled = true;

  OperationStatus? lastStatusShown;
  int lastStatusShownMs = 0;

  int lastConnectedMs = 0;
  int lastMessageReceivedMs = 0;
  int lastHealthRecoverTriggeredMs = 0;
  bool isAwaitingTypeConfirmation = false;
}

/// Socket服务（GetX Service）
/// 支持同时连接墙面服务器和桌面服务器
///
/// 说明：
/// - 通过 [WidgetsBindingObserver] 监听应用前后台切换，用于唤醒后快速恢复连接
abstract class SocketServiceBase extends GetxService with WidgetsBindingObserver {
  /// Socket客户端管理器
  late SocketClientManager _clientManager;
  
  /// UDP发现服务
  late UdpDiscoveryService _discoveryService;

  final Map<ServerType, _ServerEndpointState> _endpoints = {
    ServerType.wall: _ServerEndpointState(ServerType.wall),
    ServerType.desktop: _ServerEndpointState(ServerType.desktop),
  };
  
  /// 是否有任一服务器连接
  bool get isAnyConnected => _clientManager.isAnyConnected;
  
  /// 是否两个服务器都已连接
  bool get isAllConnected => _clientManager.isAllConnected;
  
  /// 是否正在扫描服务器
  final RxBool isScanning = false.obs;
  
  /// 发现的服务器列表
  final RxList<DiscoveredServer> discoveredServers = <DiscoveredServer>[].obs;

  final RxBool isCourseListLoading = true.obs;
  final RxList<String> courseList = <String>[].obs;

  ServerType? _courseListSource;
  
  /// 所有消息接收流控制器（合并）
  final _allMessageController = StreamController<(ServerType, MESSAGE)>.broadcast();

  /// 防止同一 ServerType 在短时间内被多处重复触发“确保连接”的并发请求
  final Map<ServerType, Future<bool>> _ensureConnectInFlight = {};

  /// 防止同一时刻多处触发 UDP 扫描，导致网络广播风暴与 UI 抖动
  Future<List<DiscoveredServer>>? _scanServersInFlight;
  
  /// 所有消息接收流（包含服务器类型信息）
  Stream<(ServerType, MESSAGE)> get allMessageStream => _allMessageController.stream;

  _ServerEndpointState _endpoint(ServerType serverType) {
    return _endpoints[serverType]!;
  }

  bool isConnected(ServerType serverType) {
    return _clientManager.getClient(serverType).isConnected;
  }

  Rx<SocketState> connectionState(ServerType serverType) {
    return _endpoint(serverType).connectionState;
  }

  RxnString connectedServerIp(ServerType serverType) {
    return _endpoint(serverType).connectedServerIp;
  }

  Stream<MESSAGE> messageStream(ServerType serverType) {
    return _endpoint(serverType).messageController.stream;
  }

  List<DiscoveredServer> discoveredServersOf(ServerType serverType) {
    final target = serverType.toClientEnd();
    return discoveredServers.where((s) => s.serverType == target).toList();
  }

  void _handleMessage(ServerType serverType, MESSAGE message);

  @override
  void onClose() {
    _clientManager.dispose();
    _discoveryService.dispose();
    for (final endpoint in _endpoints.values) {
      endpoint.messageController.close();
    }
    _allMessageController.close();
    super.onClose();
  }
}

class SocketService extends SocketServiceBase
    with
        SocketServiceSendMixin,
        SocketServiceConnectionMixin,
        SocketServiceHandleMixin {}
