///Socket通信使用示例
/// 
/// 此文件展示了如何使用Socket通信模块
/// 支持同时连接墙面服务器(WALL)和桌面服务器(Desktop)
/// 

// ignore_for_file: dangling_library_doc_comments

import 'package:get/get.dart';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'socket_client.dart';
import 'socket_client_manager.dart';
import 'socket_service.dart';
import 'udp_discovery_service.dart';

/// 示例控制器
class SocketExampleController extends GetxController {
  late final SocketService socketService;

  @override
  void onInit() {
    super.onInit();
    
    // 获取Socket服务实例
    socketService = Get.find<SocketService>();
    
    // 监听墙面服务器连接状态
    ever(socketService.wallConnectionState, _onWallStateChanged);
    
    // 监听桌面服务器连接状态
    ever(socketService.desktopConnectionState, _onDesktopStateChanged);
    
    // 监听发现的服务器列表
    ever(socketService.discoveredServers, _onServersDiscovered);
    
    // 监听墙面服务器消息
    socketService.wallMessageStream.listen(_onWallMessageReceived);
    
    // 监听桌面服务器消息
    socketService.desktopMessageStream.listen(_onDesktopMessageReceived);
    
    // 监听所有服务器消息（包含来源信息）
    socketService.allMessageStream.listen(_onAnyMessageReceived);
  }

  // ==================== 服务器发现和连接 ====================

  /// 自动发现并连接所有服务器（推荐方式）
  Future<void> autoDiscoverAndConnectAll() async {
    final results = await socketService.autoDiscoverAndConnectAll(
      timeout: const Duration(seconds: 5),
    );
    
    Get.log('墙面服务器: ${results[ServerType.wall]! ? "已连接" : "未连接"}');
    Get.log('桌面服务器: ${results[ServerType.desktop]! ? "已连接" : "未连接"}');
  }

  /// 手动扫描服务器
  Future<void> scanServers() async {
    Get.log('开始扫描服务器...');
    final servers = await socketService.scanForServers(
      timeout: const Duration(seconds: 3),
    );
    
    Get.log('发现 ${servers.length} 个服务器');
    
    // 显示墙面服务器
    final wallServers = socketService.discoveredWallServers;
    Get.log('  墙面服务器: ${wallServers.length} 个');
    for (final server in wallServers) {
      Get.log('    - ${server.ipAddress}:${server.tcpPort}');
    }
    
    // 显示桌面服务器
    final desktopServers = socketService.discoveredDesktopServers;
    Get.log('  桌面服务器: ${desktopServers.length} 个');
    for (final server in desktopServers) {
      Get.log('    - ${server.ipAddress}:${server.tcpPort}');
    }
  }

  /// 连接到发现的服务器
  Future<void> connectToDiscoveredServer(DiscoveredServer server) async {
    final success = await socketService.connectToDiscoveredServer(server);
    
    if (success) {
      Get.log('连接成功: ${server.ipAddress}');
    } else {
      Get.log('连接失败');
    }
  }

  /// 手动连接到墙面服务器
  Future<void> connectToWallServer() async {
    final success = await socketService.connectToWallServer('192.168.1.100');
    Get.log('墙面服务器连接${success ? "成功" : "失败"}');
  }

  /// 手动连接到桌面服务器
  Future<void> connectToDesktopServer() async {
    final success = await socketService.connectToDesktopServer('192.168.1.101');
    Get.log('桌面服务器连接${success ? "成功" : "失败"}');
  }

  /// 断开墙面服务器
  void disconnectWall() {
    socketService.disconnectWall();
  }

  /// 断开桌面服务器
  void disconnectDesktop() {
    socketService.disconnectDesktop();
  }

  /// 断开所有服务器
  void disconnectAll() {
    socketService.disconnectAll();
  }

  // ==================== 状态回调 ====================
  
  /// 发现的服务器列表变化回调
  void _onServersDiscovered(List<DiscoveredServer> servers) {
    Get.log('发现 ${servers.length} 个服务器');
  }
  
  /// 墙面服务器连接状态变化回调
  void _onWallStateChanged(SocketState state) {
    switch (state) {
      case SocketState.disconnected:
        Get.log('墙面服务器已断开');
        break;
      case SocketState.connecting:
        Get.log('墙面服务器连接中...');
        break;
      case SocketState.connected:
        Get.log('墙面服务器已连接');
        break;
      case SocketState.failed:
        Get.log('墙面服务器连接失败');
        break;
    }
  }
  
  /// 桌面服务器连接状态变化回调
  void _onDesktopStateChanged(SocketState state) {
    switch (state) {
      case SocketState.disconnected:
        Get.log('桌面服务器已断开');
        break;
      case SocketState.connecting:
        Get.log('桌面服务器连接中...');
        break;
      case SocketState.connected:
        Get.log('桌面服务器已连接');
        break;
      case SocketState.failed:
        Get.log('桌面服务器连接失败');
        break;
    }
  }

  // ==================== 消息接收回调 ====================

  /// 墙面服务器消息接收回调
  void _onWallMessageReceived(MESSAGE message) {
    Get.log('收到墙面服务器消息: ${message.mSGtype}');
    _handleMessage(message);
  }

  /// 桌面服务器消息接收回调
  void _onDesktopMessageReceived(MESSAGE message) {
    Get.log('收到桌面服务器消息: ${message.mSGtype}');
    _handleMessage(message);
  }

  /// 任意服务器消息接收回调（包含来源信息）
  void _onAnyMessageReceived((ServerType, MESSAGE) record) {
    final (serverType, message) = record;
    Get.log('收到${serverType.displayName}消息: ${message.mSGtype}');
  }

  /// 处理消息
  void _handleMessage(MESSAGE message) {
    switch (message.mSGtype) {
      case MSGTYPE.Status:
        _handleStatusMessage(message.mSGstatus);
        break;
      case MSGTYPE.UnityResponse:
        _handleUnityResponse(message.unityMessage);
        break;
      case MSGTYPE.ServerResponse:
        _handleServerResponse(message.serverMessage);
        break;
      case MSGTYPE.HeartEcho:
        Get.log('收到心跳响应');
        break;
      default:
        Get.log('未处理的消息类型');
    }
  }

  void _handleStatusMessage(MSGStatus status) {
    Get.log('状态: ${status.operationstatus}');
    if (status.hasInfo()) {
      Get.log('信息: ${status.info}');
    }
  }

  void _handleUnityResponse(UnityMessage unityMessage) {
    Get.log('Unity消息类型: ${unityMessage.unityMSGtype}');
    if (unityMessage.hasOperation()) {
      Get.log('操作: ${unityMessage.operation}');
    }
  }

  void _handleServerResponse(ServerMessage serverMessage) {
    Get.log('服务器行为: ${serverMessage.serverBehaviour}');
  }

  // ==================== 发送消息到墙面服务器 ====================

  /// 控制墙面服务器音量
  void setWallVolume(int volume) {
    socketService.setWallVolume(volume);
  }

  /// 打开墙面应用程序
  void openWallApplication(String appName) {
    socketService.controlApplication(ServerType.wall, appName, true);
  }

  /// 关闭墙面应用程序
  void closeWallApplication(String appName) {
    socketService.controlApplication(ServerType.wall, appName, false);
  }

  /// 发送Unity操作到墙面服务器
  void sendUnityOperationToWall(String operation) {
    socketService.sendUnityOperation(ServerType.wall, operation);
  }

  // ==================== 发送消息到桌面服务器 ====================

  /// 控制桌面服务器音量
  void setDesktopVolume(int volume) {
    socketService.setDesktopVolume(volume);
  }

  /// 打开桌面应用程序
  void openDesktopApplication(String appName) {
    socketService.controlApplication(ServerType.desktop, appName, true);
  }

  /// 关闭桌面应用程序
  void closeDesktopApplication(String appName) {
    socketService.controlApplication(ServerType.desktop, appName, false);
  }

  /// 发送Unity操作到桌面服务器
  void sendUnityOperationToDesktop(String operation) {
    socketService.sendUnityOperation(ServerType.desktop, operation);
  }

  // ==================== 发送Unity数据示例 ====================

  /// 发送人员数据到墙面Unity
  void sendPersonDataToWall() {
    final abilities = [
      Ability()
        ..abilityname = '体质'
        ..value = 85.5,
      Ability()
        ..abilityname = '智力'
        ..value = 90.0,
    ];

    final person = Person()
      ..name = '张三'
      ..num = 1
      ..uRL = 'https://example.com/avatar.jpg'
      ..abilities.addAll(abilities);

    final unityData = UnityData()
      ..specifying = 'student_info'
      ..persons.add(person);

    socketService.sendUnityData(ServerType.wall, unityData);
  }

  /// 发送表格数据到桌面Unity
  void sendBlockDataToDesktop() {
    final columns = [
      BlockColumn()
        ..name = '姓名'
        ..type = 'string'
        ..sort = 'asc'
        ..show = true,
      BlockColumn()
        ..name = '分数'
        ..type = 'number'
        ..show = true
        ..suffix = '分',
    ];

    final columnDatas = [
      BlockColumnData()
        ..columnData = '张三'
        ..separator = ',',
      BlockColumnData()
        ..columnData = '95'
        ..separator = '',
    ];

    final block = Block()
      ..name = '成绩表'
      ..index = 1
      ..blockColumns.addAll(columns)
      ..blockColumnDatas.addAll(columnDatas);

    final unityData = UnityData()
      ..specifying = 'score_table'
      ..blocks.add(block);

    socketService.sendUnityData(ServerType.desktop, unityData);
  }

  // ==================== 同时发送到两个服务器 ====================

  /// 同时设置两个服务器的音量
  void setAllVolume(int volume) {
    if (socketService.isWallConnected) {
      socketService.setWallVolume(volume);
    }
    if (socketService.isDesktopConnected) {
      socketService.setDesktopVolume(volume);
    }
  }

  /// 发送相同的服务器消息到所有已连接的服务器
  void sendToAllServers() {
    final serverMessage = ServerMessage()
      ..serverBehaviour = SERVERBEHAVIOUR.Volume
      ..volumeValue = 50;
    
    socketService.sendToAllServers(serverMessage);
  }

  @override
  void onClose() {
    socketService.disconnectAll();
    super.onClose();
  }
}

/// 在UI中使用的示例
/// 
/// ```dart
/// class SocketExamplePage extends GetView<SocketExampleController> {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Socket示例')),
///       body: Column(
///         children: [
///           // 显示墙面服务器连接状态
///           Obx(() {
///             final state = controller.socketService.wallConnectionState.value;
///             final ip = controller.socketService.connectedWallServerIp.value;
///             return Text('墙面服务器: $state ${ip ?? ""}');
///           }),
///           
///           // 显示桌面服务器连接状态
///           Obx(() {
///             final state = controller.socketService.desktopConnectionState.value;
///             final ip = controller.socketService.connectedDesktopServerIp.value;
///             return Text('桌面服务器: $state ${ip ?? ""}');
///           }),
///           
///           // 自动发现并连接
///           ElevatedButton(
///             onPressed: controller.autoDiscoverAndConnectAll,
///             child: Text('自动发现并连接'),
///           ),
///           
///           // 断开所有连接
///           ElevatedButton(
///             onPressed: controller.disconnectAll,
///             child: Text('断开所有连接'),
///           ),
///           
///           // 控制墙面音量
///           Slider(
///             value: 50,
///             min: 0,
///             max: 100,
///             onChanged: (value) => controller.setWallVolume(value.toInt()),
///           ),
///           
///           // 控制桌面音量
///           Slider(
///             value: 50,
///             min: 0,
///             max: 100,
///             onChanged: (value) => controller.setDesktopVolume(value.toInt()),
///           ),
///           
///           // 发送Unity操作到墙面
///           ElevatedButton(
///             onPressed: () => controller.sendUnityOperationToWall('StartGame'),
///             child: Text('墙面: 开始游戏'),
///           ),
///           
///           // 发送Unity操作到桌面
///           ElevatedButton(
///             onPressed: () => controller.sendUnityOperationToDesktop('StartGame'),
///             child: Text('桌面: 开始游戏'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
