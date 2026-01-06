/// SocketService 的“发送能力”集合（同一 library 的 part 文件）。
///
/// 这个 mixin 提供对外常用的发送 API：
/// - 发送到 PC 服务端：sendToServer / sendToAllServers
/// - 通过 PC 转发到 Unity：sendToUnity + sendUnityOperation/sendUnityData
/// - 业务便捷方法：requestCourseList / setVolume / controlApplication / sendHeartbeat
///
/// 并在内部封装 protobuf 消息的外层包装（ServerRequest/UnityRequest/HeartEcho）。
///
/// 说明：该文件是 part of socket_service.dart，不应被独立 import/export。
part of 'socket_service.dart';

mixin SocketServiceSendMixin on SocketServiceBase {
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

  // ==================== 便捷方法 ====================

  /// 向指定服务器发送“获取课程清单”的请求，并将本地清单状态重置为加载中
  void requestCourseList(ServerType serverType) {
    if (courseList.isEmpty) {
      isCourseListLoading.value = true;
    }

    final serverMessage = ServerMessage()..serverBehaviour = SERVERBEHAVIOUR.CourseList;
    sendToServer(serverType, serverMessage);
  }

  /// 控制音量
  void setVolume(ServerType serverType, int volume) {
    final serverMessage = ServerMessage()
      ..serverBehaviour = SERVERBEHAVIOUR.Volume
      ..volumeValue = volume;

    sendToServer(serverType, serverMessage);
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

  MESSAGE _buildServerRequest(ServerMessage serverMessage) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.ServerRequest
      ..serverMessage = serverMessage;
  }

  MESSAGE _buildUnityRequest(UnityMessage unityMessage) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.UnityRequest
      ..unityMessage = unityMessage;
  }

  MESSAGE _buildHeartbeat(ServerType serverType) {
    return MESSAGE()
      ..mSGtype = MSGTYPE.HeartEcho
      ..echoData = (EchoData()..clientEnd = serverType.toClientEnd());
  }
}
