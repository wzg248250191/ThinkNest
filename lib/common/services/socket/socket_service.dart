// ignore_for_file: unnecessary_string_interpolations

import 'dart:async';
import 'package:get/get.dart';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'socket_client.dart';
import 'socket_client_manager.dart';
import 'udp_discovery_service.dart';

/// Socket服务（GetX Service）
/// 支持同时连接墙面服务器和桌面服务器
class SocketService extends GetxService {
  /// Socket客户端管理器
  late SocketClientManager _clientManager;
  
  /// UDP发现服务
  late UdpDiscoveryService _discoveryService;
  
  /// 墙面服务器连接状态
  final Rx<SocketState> wallConnectionState = SocketState.disconnected.obs;
  
  /// 桌面服务器连接状态
  final Rx<SocketState> desktopConnectionState = SocketState.disconnected.obs;
  
  /// 墙面服务器是否已连接
  bool get isWallConnected => _clientManager.isWallConnected;
  
  /// 桌面服务器是否已连接
  bool get isDesktopConnected => _clientManager.isDesktopConnected;
  
  /// 是否有任一服务器连接
  bool get isAnyConnected => _clientManager.isAnyConnected;
  
  /// 是否两个服务器都已连接
  bool get isAllConnected => _clientManager.isAllConnected;
  
  /// 是否正在扫描服务器
  final RxBool isScanning = false.obs;
  
  /// 发现的服务器列表
  final RxList<DiscoveredServer> discoveredServers = <DiscoveredServer>[].obs;
  
  /// 发现的墙面服务器列表
  List<DiscoveredServer> get discoveredWallServers => 
      discoveredServers.where((s) => s.serverType == CLIENTEND.WALL).toList();
  
  /// 发现的桌面服务器列表
  List<DiscoveredServer> get discoveredDesktopServers => 
      discoveredServers.where((s) => s.serverType == CLIENTEND.Desktop).toList();
  
  /// 当前连接的墙面服务器IP
  final RxnString connectedWallServerIp = RxnString();
  
  /// 当前连接的桌面服务器IP
  final RxnString connectedDesktopServerIp = RxnString();
  
  /// 墙面服务器消息接收流控制器
  final _wallMessageController = StreamController<MESSAGE>.broadcast();
  
  /// 桌面服务器消息接收流控制器
  final _desktopMessageController = StreamController<MESSAGE>.broadcast();
  
  /// 所有消息接收流控制器（合并）
  final _allMessageController = StreamController<(ServerType, MESSAGE)>.broadcast();
  
  /// 墙面服务器消息接收流
  Stream<MESSAGE> get wallMessageStream => _wallMessageController.stream;
  
  /// 桌面服务器消息接收流
  Stream<MESSAGE> get desktopMessageStream => _desktopMessageController.stream;
  
  /// 所有消息接收流（包含服务器类型信息）
  Stream<(ServerType, MESSAGE)> get allMessageStream => _allMessageController.stream;

  @override
  void onInit() {
    super.onInit();
    _initClientManager();
    _initDiscoveryService();
  }

  /// 构建发送给PC服务器的 `ServerRequest` 外层消息
  MESSAGE _buildServerRequest(ServerMessage serverMessage) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.ServerRequest
      ..serverMessage = serverMessage;
  }

  /// 构建发送给PC服务器的 `UnityRequest` 外层消息
  MESSAGE _buildUnityRequest(UnityMessage unityMessage) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.UnityRequest
      ..unityMessage = unityMessage;
  }

  /// 构建发送给指定服务器的心跳消息
  MESSAGE _buildHeartbeat(ServerType serverType) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.HeartEcho
      ..echoData = (EchoData()..clientEnd = serverType.toClientEnd());
  }

  /// 同步指定服务器的连接状态到响应式字段
  void _onServerStateChanged(ServerType serverType, SocketState state) {
    switch (serverType) {
      case ServerType.wall:
        wallConnectionState.value = state;
        if (state == SocketState.disconnected) {
          connectedWallServerIp.value = null;
        }
        break;
      case ServerType.desktop:
        desktopConnectionState.value = state;
        if (state == SocketState.disconnected) {
          connectedDesktopServerIp.value = null;
        }
        break;
    }
  }

  /// 分发指定服务器的消息到对应 stream，并触发内部消息处理
  void _onServerMessageReceived(ServerType serverType, MESSAGE message) {
    switch (serverType) {
      case ServerType.wall:
        _wallMessageController.add(message);
        break;
      case ServerType.desktop:
        _desktopMessageController.add(message);
        break;
    }
    _allMessageController.add((serverType, message));
    _handleMessage(serverType, message);
  }

  /// 初始化Socket客户端管理器
  void _initClientManager() {
    _clientManager = SocketClientManager();
    
    _clientManager.onWallStateChanged =
        (state) => _onServerStateChanged(ServerType.wall, state);
    _clientManager.onWallMessageReceived =
        (message) => _onServerMessageReceived(ServerType.wall, message);
    _clientManager.onDesktopStateChanged =
        (state) => _onServerStateChanged(ServerType.desktop, state);
    _clientManager.onDesktopMessageReceived =
        (message) => _onServerMessageReceived(ServerType.desktop, message);
    
    _clientManager.onError = (serverType, error) {
      print('${serverType.displayName}错误: $error');
      Get.snackbar('${serverType.displayName}错误', error);
    };
  }
  
  /// 初始化UDP发现服务
  void _initDiscoveryService() {
    _discoveryService = UdpDiscoveryService();
    
    _discoveryService.onServerDiscovered = (server) {
      if (!discoveredServers.contains(server)) {
        discoveredServers.add(server);
        print('发现${server.serverType == CLIENTEND.WALL ? "墙面" : "桌面"}服务器: ${server.ipAddress}');
      }
    };
    
    _discoveryService.onScanComplete = (servers) {
      isScanning.value = false;
    };
    
    _discoveryService.onError = (error) {
      print('UDP发现错误: $error');
    };
  }

  // ==================== 服务器发现 ====================
  
  /// 扫描局域网内的服务器
  Future<List<DiscoveredServer>> scanForServers({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    isScanning.value = true;
    discoveredServers.clear();
    
    final servers = await _discoveryService.startDiscovery(
      timeout: timeout,
      retryCount: 3,
    );
    
    isScanning.value = false;
    return servers;
  }

  // ==================== 连接管理 ====================

  /// 连接到服务器
  Future<bool> connect(ServerType serverType, String host, int port) async {
    final success = await _clientManager.connect(serverType, host, port);
    if (success) {
      switch (serverType) {
        case ServerType.wall:
          connectedWallServerIp.value = host;
          break;
        case ServerType.desktop:
          connectedDesktopServerIp.value = host;
          break;
      }
    }
    return success;
  }

  /// 连接到墙面服务器（默认端口8000）
  Future<bool> connectToWallServer(String host, {int port = 8000}) async {
    return await connect(ServerType.wall, host, port);
  }

  /// 连接到桌面服务器（默认端口8000）
  Future<bool> connectToDesktopServer(String host, {int port = 8000}) async {
    return await connect(ServerType.desktop, host, port);
  }

  /// 连接到发现的服务器
  Future<bool> connectToDiscoveredServer(DiscoveredServer server) async {
    final serverType = ServerTypeExtension.fromClientEnd(server.serverType);
    return await connect(serverType, server.ipAddress, server.tcpPort);
  }

  /// 自动发现并连接所有服务器
  Future<Map<ServerType, bool>> autoDiscoverAndConnectAll({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    print('开始自动发现服务器...');
    final servers = await scanForServers(timeout: timeout);
    
    final results = <ServerType, bool>{
      ServerType.wall: false,
      ServerType.desktop: false,
    };
    
    // 连接墙面服务器
    final wallServer = servers.where((s) => s.serverType == CLIENTEND.WALL).firstOrNull;
    if (wallServer != null) {
      results[ServerType.wall] = await connectToDiscoveredServer(wallServer);
      print('墙面服务器连接${results[ServerType.wall]! ? "成功" : "失败"}');
    } else {
      print('未找到墙面服务器');
    }
    
    // 连接桌面服务器
    final desktopServer = servers.where((s) => s.serverType == CLIENTEND.Desktop).firstOrNull;
    if (desktopServer != null) {
      results[ServerType.desktop] = await connectToDiscoveredServer(desktopServer);
      print('桌面服务器连接${results[ServerType.desktop]! ? "成功" : "失败"}');
    } else {
      print('未找到桌面服务器');
    }
    
    return results;
  }

  /// 断开服务器连接
  void disconnect(ServerType serverType) {
    _clientManager.disconnect(serverType);
  }

  /// 断开墙面服务器
  void disconnectWall() {
    _clientManager.disconnectWall();
  }

  /// 断开桌面服务器
  void disconnectDesktop() {
    _clientManager.disconnectDesktop();
  }

  /// 断开所有服务器
  void disconnectAll() {
    _clientManager.disconnectAll();
  }

  // ==================== 发送消息到PC服务器 ====================

  /// 发送ServerRequest消息到指定服务器
  /// 
  /// 说明：
  /// - 业务侧只需要构造 `ServerMessage`，此处会包一层 `MESSAGE(MSGTYPE.ServerRequest)`
  /// - 最终由底层 SocketClient 完成：封包（头+长度+cmd）→ 写入 TCP Socket
  void sendToServer(ServerType serverType, ServerMessage serverMessage) {
    _clientManager.sendTo(serverType, _buildServerRequest(serverMessage));
    print('发送服务器消息到${serverType.displayName}: ${serverMessage.serverBehaviour}');
  }

  /// 发送消息到墙面服务器
  void sendToWallServer(ServerMessage serverMessage) {
    sendToServer(ServerType.wall, serverMessage);
  }

  /// 发送消息到桌面服务器
  void sendToDesktopServer(ServerMessage serverMessage) {
    sendToServer(ServerType.desktop, serverMessage);
  }

  /// 发送消息到所有已连接的服务器
  void sendToAllServers(ServerMessage serverMessage) {
    _clientManager.sendToAll(_buildServerRequest(serverMessage));
  }

  // ==================== 发送消息到Unity（通过PC服务器中转）====================

  /// 发送UnityRequest消息到指定服务器转发给Unity
  /// 
  /// 说明：
  /// - 该消息会由 PC 端作为中转，转发给 Unity 程序处理
  /// - 适用于 Unity 的 Operation/Data 两类控制消息
  void sendToUnity(ServerType serverType, UnityMessage unityMessage) {
    _clientManager.sendTo(serverType, _buildUnityRequest(unityMessage));
    print('发送Unity消息到${serverType.displayName}: ${unityMessage.unityMSGtype}');
  }

  /// 通过墙面服务器发送消息到Unity
  void sendToUnityViaWall(UnityMessage unityMessage) {
    sendToUnity(ServerType.wall, unityMessage);
  }

  /// 通过桌面服务器发送消息到Unity
  void sendToUnityViaDesktop(UnityMessage unityMessage) {
    sendToUnity(ServerType.desktop, unityMessage);
  }

  // ==================== 便捷方法 ====================

  /// 控制音量
  void setVolume(ServerType serverType, int volume) {
    final serverMessage = ServerMessage()
      ..serverBehaviour = SERVERBEHAVIOUR.Volume
      ..volumeValue = volume;
    
    sendToServer(serverType, serverMessage);
  }

  /// 控制墙面服务器音量
  void setWallVolume(int volume) {
    setVolume(ServerType.wall, volume);
  }

  /// 控制桌面服务器音量
  void setDesktopVolume(int volume) {
    setVolume(ServerType.desktop, volume);
  }

  /// 打开/关闭应用程序
  /// 
  /// 说明：
  /// - 这是“打开/关闭课程（应用）”的关键入口：对应 PC/Unity 端的 Application 控制
  /// - `appName` 对应服务端/Unity 侧的 GameName（课程名/程序名）
  /// - `open=true` 表示开启，`open=false` 表示关闭
  void controlApplication(ServerType serverType, String appName, bool open) {
    final serverMessage = ServerMessage()
      ..serverBehaviour = SERVERBEHAVIOUR.Application
      ..gameName = appName
      ..on = open;
    
    sendToServer(serverType, serverMessage);
  }

  /// 发送Unity操作指令
  void sendUnityOperation(ServerType serverType, String operation) {
    final unityMessage = UnityMessage()
      ..unityMSGtype = UNITYMSGTYPE.Operation
      ..operation = operation;
    
    sendToUnity(serverType, unityMessage);
  }

  /// 发送Unity数据
  void sendUnityData(ServerType serverType, UnityData data) {
    final unityMessage = UnityMessage()
      ..unityMSGtype = UNITYMSGTYPE.Data
      ..unityData = data;
    
    sendToUnity(serverType, unityMessage);
  }

  /// 发送心跳消息
  void sendHeartbeat(ServerType serverType) {
    _clientManager.sendTo(serverType, _buildHeartbeat(serverType));
  }

  // ==================== 消息处理 ====================

  /// 处理接收到的消息
  void _handleMessage(ServerType serverType, MESSAGE message) {
    switch (message.mSGtype) {
      case MSGTYPE.Status:
        _handleStatusMessage(serverType, message.mSGstatus);
        break;
      case MSGTYPE.UnityResponse:
        _handleUnityResponse(serverType, message.unityMessage);
        break;
      case MSGTYPE.ServerResponse:
        _handleServerResponse(serverType, message.serverMessage);
        break;
      case MSGTYPE.HeartEcho:
        print('收到${serverType.displayName}心跳响应');
        break;
      default:
        print('收到${serverType.displayName}未处理的消息类型: ${message.mSGtype}');
    }
  }

  /// 处理状态消息
  void _handleStatusMessage(ServerType serverType, MSGStatus status) {
    print('收到${serverType.displayName}状态消息: ${status.operationstatus}, 信息: ${status.info}');
    
    switch (status.operationstatus) {
      case OperationStatus.NullUnityClient:
        Get.snackbar('${serverType.displayName}', 'Unity客户端未连接');
        break;
      case OperationStatus.NulliPadClient:
        Get.snackbar('${serverType.displayName}', 'iPad客户端未连接');
        break;
      case OperationStatus.NullCourse:
        Get.snackbar('${serverType.displayName}', '课程不存在');
        break;
      case OperationStatus.CoursePlayisRunning:
        Get.snackbar('${serverType.displayName}', '课程正在运行中');
        break;
      case OperationStatus.DataformatterError:
        Get.snackbar('${serverType.displayName}', '数据格式错误');
        break;
      case OperationStatus.DataTransferError:
        Get.snackbar('${serverType.displayName}', '数据传输错误');
        break;
    }
  }

  /// 处理Unity响应
  void _handleUnityResponse(ServerType serverType, UnityMessage unityMessage) {
    print('收到${serverType.displayName}的Unity响应: ${unityMessage.unityMSGtype}');
  }

  /// 处理服务器响应
  void _handleServerResponse(ServerType serverType, ServerMessage serverMessage) {
    print('收到${serverType.displayName}响应: ${serverMessage.serverBehaviour}');
  }

  /// 获取发现服务（用于高级用法）
  UdpDiscoveryService get discoveryService => _discoveryService;
  
  /// 获取客户端管理器（用于高级用法）
  SocketClientManager get clientManager => _clientManager;

  @override
  void onClose() {
    _clientManager.dispose();
    _discoveryService.dispose();
    _wallMessageController.close();
    _desktopMessageController.close();
    _allMessageController.close();
    super.onClose();
  }
}
