import 'dart:async';

import 'package:get/get.dart';

import '../../../common/index.dart';
import '../../index.dart';

/// 课程详情控制器（负责页面状态、交互与指令收发）
class SingleCourseController extends GetxController {
  SingleCourseController();

  final SingleCourseCommandRepository _repo = Get.find<SingleCourseCommandRepository>();
  final CommandChannelService _channel = Get.find<CommandChannelService>();

  StreamSubscription<CommandMessage>? _sub;

  String? courseId;

  int controlSelectedIndex = 0;

  bool wallEnabled = false;
  bool deskEnabled = false;
  bool wholeEnabled = false;
  int wallVolume = 100;
  int deskVolume = 100;

  /// 打开课程详情并初始化状态（用于覆盖层展示）
  Future<void> openCourse(String courseId) async {
    this.courseId = courseId;
    controlSelectedIndex = 0;
    await _channel.ensureConnected();
    await _repo.subscribeCourse(courseId: courseId);
    _subscribeInbound();
    await _repo.requestInitialState(courseId: courseId);
    update(['course_detail', 'course_control_toggle', 'course_switches']);
  }

  /// 关闭课程详情并释放订阅
  Future<void> closeCourse() async {
    final String? id = courseId;
    courseId = null;
    _sub?.cancel();
    _sub = null;
    if (id != null) {
      await _repo.unsubscribeCourse(courseId: id);
    }
    update(['course_detail', 'course_control_toggle', 'course_switches']);
  }

  /// 切换左侧互斥按钮选中项
  void setControlSelectedIndex(int index) {
    controlSelectedIndex = index;
    update(['type_switch']);
  }

  Future<void> setWholeEnabled(bool enabled) async{
    final String? id = courseId;
    if (id == null) {
      return;
    }
    wallEnabled = enabled;  
    deskEnabled = enabled;
    wholeEnabled = enabled;
    update(['course_control_toggle']);
    await _repo.setWallEnabled(courseId: id, enabled: enabled);
    await _repo.setDeskEnabled(courseId: id, enabled: enabled);
  }

  /// 设置墙面开关并发送指令
  Future<void> setWallEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    wallEnabled = enabled;
    if(deskEnabled==enabled){
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
    await _repo.setWallEnabled(courseId: id, enabled: enabled);
  }

  /// 设置桌面开关并发送指令
  Future<void> setDeskEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    deskEnabled = enabled;
     if(wallEnabled==enabled){
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
    await _repo.setDeskEnabled(courseId: id, enabled: enabled);
  }

  /// 设置墙面音量并发送指令
  Future<void> setWallVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);
    await _repo.setWallVolume(courseId: id, volume: wallVolume);
  }

  /// 设置桌面音量并发送指令
  Future<void> setDeskVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);
    await _repo.setDeskVolume(courseId: id, volume: deskVolume);  
  }


  void _subscribeInbound() {
    _sub?.cancel();
    _sub = _channel.inboundStream.listen(_onInboundMessage);
  }

  /// 处理服务器推送的课程相关消息
  void _onInboundMessage(CommandMessage msg) {
    final String? id = courseId;
    if (id == null || msg.courseId != id) {
      return;
    }

    switch (msg.type) {
      case 'course.wall.state':
        final bool? enabled = msg.data['enabled'] as bool?;
        if (enabled != null) {
          wallEnabled = enabled;
          update(['course_switches']);
        }
        break;
      case 'course.desk.state':
        final bool? enabled = msg.data['enabled'] as bool?;
        if (enabled != null) {
          deskEnabled = enabled;
          update(['course_switches']);
        }
        break;
      default:
        break;
    }
  }

  @override
  /// 控制器销毁时释放订阅
  void onClose() {
    _sub?.cancel();
    _sub = null;
    super.onClose();
  }
}
