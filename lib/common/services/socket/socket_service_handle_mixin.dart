/// SocketService 的“消息处理能力”集合（同一 library 的 part 文件）。
///
/// 这个 mixin 专注于“收到消息以后怎么处理”：
/// - 统一入口：_handleMessage(serverType, message)
/// - 按 MSGTYPE 分派：Status/ServerResponse/UnityResponse/HeartEcho
/// - 维护上层响应式状态：例如课程清单、加载状态等
///
/// 说明：该文件是 part of socket_service.dart，不应被独立 import/export。
part of 'socket_service.dart';

mixin SocketServiceHandleMixin on SocketServiceBase {
  // ==================== 消息处理 ====================

  /// 处理接收到的消息
  @override
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

    final op = status.operationstatus;
    if (!_shouldShowStatusSnackbar(serverType, op)) {
      return;
    }
  }

  bool _shouldShowStatusSnackbar(ServerType serverType, OperationStatus status) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final endpoint = _endpoint(serverType);

    if (endpoint.lastStatusShown == status && (nowMs - endpoint.lastStatusShownMs) < 1500) {
      return false;
    }
    if ((nowMs - endpoint.lastStatusShownMs) < 800) {
      return false;
    }
    endpoint.lastStatusShown = status;
    endpoint.lastStatusShownMs = nowMs;
    return true;
  }

  /// 处理Unity响应
  void _handleUnityResponse(ServerType serverType, UnityMessage unityMessage) {
    print('收到${serverType.displayName}的Unity响应: ${unityMessage.unityMSGtype}');
  }

  /// 处理服务器响应
  void _handleServerResponse(ServerType serverType, ServerMessage serverMessage) {
    switch (serverMessage.serverBehaviour) {
      case SERVERBEHAVIOUR.CourseList:
        courseList.assignAll(serverMessage.courseList);
        isCourseListLoading.value = false;
        unawaited(Storage().setList(_courseListCacheKey, serverMessage.courseList));
        print('收到${serverType.displayName}课程清单: ${courseList.length}');
        break;
      default:
        print('收到${serverType.displayName}响应: ${serverMessage.serverBehaviour}');
        break;
    }
  }
}
