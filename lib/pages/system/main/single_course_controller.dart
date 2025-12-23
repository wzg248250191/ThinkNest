import 'dart:async';

import 'package:get/get.dart';

import '../../../common/index.dart';
import '../../index.dart';

/// 课程详情控制器（负责页面状态、交互与指令收发）
class SingleCourseController extends GetxController {
  SingleCourseController();

  final SingleCourseCommandRepository _repo = Get.find<SingleCourseCommandRepository>();
  
  /// 获取 SocketService 实例
  SocketService get _socketService => Get.find<SocketService>();
  
  /// CommandChannelService（可选，用于 WebSocket 通信）
  CommandChannelService? get _channel {
    if (Get.isRegistered<CommandChannelService>()) {
      return Get.find<CommandChannelService>();
    }
    return null;
  }

  StreamSubscription<CommandMessage>? _sub;

  String? courseId;

  int controlSelectedIndex = 0;

  bool wallEnabled = false;
  bool deskEnabled = false;
  bool wholeEnabled = false;
  int wallVolume = 100;
  int deskVolume = 100;
  
  /// 墙面服务器是否已连接
  bool get isWallConnected => _socketService.isWallConnected;
  
  /// 桌面服务器是否已连接
  bool get isDeskConnected => _socketService.isDesktopConnected;
  
  /// 获取墙面服务器连接IP
  String? get wallServerIp => _socketService.connectedWallServerIp.value;
  
  /// 获取桌面服务器连接IP
  String? get deskServerIp => _socketService.connectedDesktopServerIp.value;

  /// 打开课程详情并初始化状态（用于覆盖层展示）
  /// 
  /// 说明：
  /// - 用户点击课程卡片后会进入此方法
  /// - 不会主动发送 TCP 指令；TCP 指令由开关操作触发
  /// - WebSocket 订阅属于辅助能力，失败不会影响 TCP 侧的开启/关闭
  Future<void> openCourse(String courseId) async {
    this.courseId = courseId;
    controlSelectedIndex = 0;
    
    // 重置状态
    wallEnabled = false;
    deskEnabled = false;
    wholeEnabled = false;
    wallVolume = 100;
    deskVolume = 100;

    // 尝试连接 WebSocket（可选）
    try {
      await _channel?.ensureConnected();
      await _repo.subscribeCourse(courseId: courseId);
      _subscribeInbound();
      await _repo.requestInitialState(courseId: courseId);
    } catch (e) {
      print('WebSocket 连接失败（非必需）: $e');
    }
    
    update(['course_detail', 'course_control_toggle', 'course_switches']);
  }

  /// 关闭课程详情并释放订阅
  Future<void> closeCourse() async {
    final String? id = courseId;
    courseId = null;
    _sub?.cancel();
    _sub = null;
    if (id != null) {
      try {
        await _repo.unsubscribeCourse(courseId: id);
      } catch (e) {
        print('取消订阅失败（非必需）: $e');
      }
    }
    update(['course_detail', 'course_control_toggle', 'course_switches']);
  }

  /// 切换左侧互斥按钮选中项
  void setControlSelectedIndex(int index) {
    controlSelectedIndex = index;
    update(['type_switch']);
  }

  /// 设置整体控制开关（同时控制墙面和桌面）
  Future<void> setWholeEnabled(bool enabled) async{
    final String? id = courseId;
    if (id == null) {
      return;
    }
    
    // 通过 TCP Socket 发送课程开启/关闭命令到两个 PC 服务器
    bool wallSuccess;
    bool deskSuccess;
    
    if (enabled) {
      wallSuccess = await _repo.openWallCourse(courseId: id);
      deskSuccess = await _repo.openDeskCourse(courseId: id);
    } else {
      wallSuccess = await _repo.closeWallCourse(courseId: id);
      deskSuccess = await _repo.closeDeskCourse(courseId: id);
    }
    
    // 根据连接状态更新 UI
    if (wallSuccess) {
      wallEnabled = enabled;
    }
    if (deskSuccess) {
      deskEnabled = enabled;
    }
    
    // 只有两个都成功才更新整体状态
    if (wallSuccess && deskSuccess) {
      wholeEnabled = enabled;
    } else if (!wallSuccess && !deskSuccess) {
      Get.snackbar('提示', '墙面和桌面服务器均未连接');
    } else if (!wallSuccess) {
      Get.snackbar('提示', '墙面服务器未连接');
    } else {
      Get.snackbar('提示', '桌面服务器未连接');
    }
    
    update(['course_control_toggle']);
    // 同时通过 WebSocket 同步状态（如果需要）
    if (wallSuccess) {
      await _repo.setWallEnabled(courseId: id, enabled: enabled);
    }
    if (deskSuccess) {
      await _repo.setDeskEnabled(courseId: id, enabled: enabled);
    }
  }

  /// 设置墙面开关并发送指令（通过 TCP Socket 发送到墙面 PC 服务器）
  Future<void> setWallEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    
    // 通过 TCP Socket 发送课程开启/关闭命令到墙面 PC 服务器
    bool success;
    if (enabled) {
      success = await _repo.openWallCourse(courseId: id);
    } else {
      success = await _repo.closeWallCourse(courseId: id);
    }
    
    if (!success) {
      Get.snackbar('提示', '墙面服务器未连接，请先连接服务器');
      return;
    }
    
    wallEnabled = enabled;
    if(deskEnabled==enabled){
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
    // 同时通过 WebSocket 同步状态（如果需要）
    await _repo.setWallEnabled(courseId: id, enabled: enabled);
  }

  /// 设置桌面开关并发送指令（通过 TCP Socket 发送到桌面 PC 服务器）
  Future<void> setDeskEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    
    // 通过 TCP Socket 发送课程开启/关闭命令到桌面 PC 服务器
    bool success;
    if (enabled) {
      success = await _repo.openDeskCourse(courseId: id);
    } else {
      success = await _repo.closeDeskCourse(courseId: id);
    }
    
    if (!success) {
      Get.snackbar('提示', '桌面服务器未连接，请先连接服务器');
      return;
    }
    
    deskEnabled = enabled;
     if(wallEnabled==enabled){
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
    // 同时通过 WebSocket 同步状态（如果需要）
    await _repo.setDeskEnabled(courseId: id, enabled: enabled);
  }

  /// 设置墙面音量（仅更新本地状态，不发送到服务器）
  void setWallVolume(int value) {
    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  /// 提交墙面音量（拖动/点击结束时发送到服务器）
  Future<void> commitWallVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);

    await _repo.setWallCourseVolume(volume: wallVolume);
    await _repo.setWallVolume(courseId: id, volume: wallVolume);
  }

  /// 设置桌面音量（仅更新本地状态，不发送到服务器）
  void setDeskVolume(int value) {
    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  /// 提交桌面音量（拖动/点击结束时发送到服务器）
  Future<void> commitDeskVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);

    await _repo.setDeskCourseVolume(volume: deskVolume);
    await _repo.setDeskVolume(courseId: id, volume: deskVolume);
  }


  void _subscribeInbound() {
    _sub?.cancel();
    final channel = _channel;
    if (channel != null) {
      _sub = channel.inboundStream.listen(_onInboundMessage);
    }
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
