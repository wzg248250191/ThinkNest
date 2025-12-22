import 'package:get/get.dart';

import '../../../common/index.dart';

/// 课程详情相关指令仓库（封装协议与发送逻辑）
class SingleCourseCommandRepository {
  final CommandChannelService _channel = Get.find<CommandChannelService>();

  /// 订阅指定课程的实时事件
  Future<void> subscribeCourse({required String courseId}) async {
    await _send(
      type: 'course.subscribe',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 取消订阅指定课程的实时事件
  Future<void> unsubscribeCourse({required String courseId}) async {
    await _send(
      type: 'course.unsubscribe',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 请求服务器推送当前课程的初始状态
  Future<void> requestInitialState({required String courseId}) async {
    await _send(
      type: 'course.state.get',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 设置墙面开关
  Future<void> setWallEnabled({
    required String courseId,
    required bool enabled,
  }) async {
    await _send(
      type: 'course.wall.set',
      courseId: courseId,
      data: <String, dynamic>{'enabled': enabled},
    );
  }

  /// 设置桌面开关
  Future<void> setDeskEnabled({
    required String courseId,
    required bool enabled,
  }) async {
    await _send(
      type: 'course.desk.set',
      courseId: courseId,
      data: <String, dynamic>{'enabled': enabled},
    );
  }

  /// 设置音量
  Future<void> setWallVolume({
    required String courseId,
    required int volume,
  }) async {
    await _send(
      type: 'course.volume.set',
      courseId: courseId,
      data: <String, dynamic>{'volume': volume},
    );
  }
  /// 设置桌面音量
  Future<void> setDeskVolume({
    required String courseId,
    required int volume,
  }) async {
    await _send(
      type: 'course.volume.set',
      courseId: courseId,
      data: <String, dynamic>{'volume': volume},
    );
  }
  

  /// 发送课程相关指令
  Future<void> _send({
    required String type,
    required String courseId,
    required Map<String, dynamic> data,
  }) async {
    await _channel.send(_buildMessage(
      type: type,
      courseId: courseId,
      data: data,
    ));
  }

  /// 构建指令消息
  CommandMessage _buildMessage({
    required String type,
    required String courseId,
    required Map<String, dynamic> data,
  }) {
    return CommandMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      courseId: courseId,
      data: data,
      timestamp: DateTime.now(),
    );
  }
}
