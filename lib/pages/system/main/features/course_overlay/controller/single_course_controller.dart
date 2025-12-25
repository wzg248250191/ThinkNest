// ignore_for_file: unnecessary_null_comparison

import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';
import '../../../../../index.dart';

class SingleCourseController extends GetxController {
  SingleCourseController();

  final PcCourseCommandSender _sender = Get.find<PcCourseCommandSender>();
  final PcCourseMessageHandler _handler = Get.find<PcCourseMessageHandler>();

  SocketService get _socketService => Get.find<SocketService>();

  String? courseId;

  int controlSelectedIndex = 0;

  bool wallEnabled = false;
  bool deskEnabled = false;
  bool wholeEnabled = false;
  int wallVolume = 100;
  int deskVolume = 100;

  bool get isWallConnected => _socketService.isWallConnected;

  bool get isDeskConnected => _socketService.isDesktopConnected;

  String? get wallServerIp => _socketService.connectedWallServerIp.value;

  String? get deskServerIp => _socketService.connectedDesktopServerIp.value;

  @override
  void onInit() {
    super.onInit();

    // 监听全局操作状态，在界面显示提示
    ever<OperationStatus?>(_handler.lastOperationStatus, (status) {
      if (status == null) return;
      
      // 只有在课程详情页显示时才弹窗
      final mainController = Get.find<MainController>();
      if (!mainController.showCourseDetail) {
        return;
      }
      
      String? msg;
      switch (status) {
        case OperationStatus.NullUnityClient:
          msg = 'Unity客户端未连接';
          break;
        case OperationStatus.NulliPadClient:
          msg = 'iPad客户端未连接';
          break;
        case OperationStatus.NullCourse:
          msg = '主机上没有对应的课程';
          break;
        case OperationStatus.CoursePlayisRunning:
          msg = '课程正在运行中';
          break;
        case OperationStatus.DataformatterError:
          msg = '数据格式错误';
          break;
        case OperationStatus.DataTransferError:
          msg = '数据传输错误';
          break;
        default:
          return;
      }

      if (msg != null) {
        final info = _handler.lastStatusInfo.value;
        final fullMsg = (info != null && info.isNotEmpty) ? '$msg: $info' : msg;
        
        // 使用全屏 Dialog 弹窗
        ToastUtils.show(fullMsg, type: ToastType.error);
      }
    });

    ever<SocketState>(
      _socketService.wallConnectionState,
      (_) {
        if (courseId != null) {
          update(['course_control_toggle']);
        }
      },
    );
    ever<SocketState>(
      _socketService.desktopConnectionState,
      (_) {
        if (courseId != null) {
          update(['course_control_toggle']);
        }
      },
    );

    ever<bool>(_handler.wallCourseEnabled, (enabled) {
      if (courseId == null) {
        return;
      }
      wallEnabled = enabled;
      if (deskEnabled == enabled) {
        wholeEnabled = enabled;
      }
      update(['course_control_toggle', 'course_switches']);
    });

    ever<bool>(_handler.deskCourseEnabled, (enabled) {
      if (courseId == null) {
        return;
      }
      deskEnabled = enabled;
      if (wallEnabled == enabled) {
        wholeEnabled = enabled;
      }
      update(['course_control_toggle', 'course_switches']);
    });

    ever<int>(_handler.wallVolume, (value) {
      if (courseId == null) {
        return;
      }
      wallVolume = value.clamp(0, 100);
      update(['volume_slider']);
    });

    ever<int>(_handler.deskVolume, (value) {
      if (courseId == null) {
        return;
      }
      deskVolume = value.clamp(0, 100);
      update(['volume_slider']);
    });
  }

  Future<void> openCourse(String courseId) async {
    // 强制让出 UI 线程，防止同步死锁，并给 UI 构建留出时间
    await Future.delayed(const Duration(milliseconds: 50));
    
    // 1. 如果打开的是“当前正在运行”的课程，则直接复用 Handler 中的状态
    //    这解决了“返回再进入时状态丢失”的问题
    if (_handler.currentCourseId.value == courseId) {
       this.courseId = courseId;
       controlSelectedIndex = 0;
       
       // 同步 Handler 中的真实状态到 UI 变量
       wallEnabled = _handler.wallCourseEnabled.value;
       deskEnabled = _handler.deskCourseEnabled.value;
       wholeEnabled = wallEnabled && deskEnabled;
       
       // 不需要调用 resetLocalState，因为状态已经是最新的
    } else {
       // 2. 如果打开的是一个新课程，则才需要重置状态
       this.courseId = null;
       controlSelectedIndex = 0;

       wallEnabled = false;
       deskEnabled = false;
       wholeEnabled = false;  
    
       // 重置 Handler 状态
       _handler.resetLocalState(enabled: false);
       _handler.attachCourse(courseId);
       
       this.courseId = courseId;
    }

    // 分批次更新，避免一次性刷新太多组件导致掉帧
    update(['course_detail', 'course_control_toggle']);
    await Future.delayed(Duration.zero);
    update(['course_switches', 'type_switch', 'volume_slider']);
  }

  Future<void> closeCourse() async {
    // 确保 courseId 立即置空，阻止后续 Worker 更新
    courseId = null;
    controlSelectedIndex = 0;
    wallEnabled = false;
    deskEnabled = false;
    wholeEnabled = false;
    
    _handler.detachCourse();
    
    // 强制让出 UI 线程，确保状态清理不会阻塞 UI 隐藏动画
    await Future.delayed(Duration.zero);
    
    update([
      'course_detail',
      'course_control_toggle',
      'course_switches',
      'type_switch',
      'volume_slider',
    ]);
  }

  void setControlSelectedIndex(int index) {
    if (controlSelectedIndex == index) {
      return;
    }
    controlSelectedIndex = index;
    update(['type_switch']);
  }

  Future<void> setWholeEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    bool wallSuccess;
    bool deskSuccess;

    if (enabled) {
      wallSuccess = await _sender.openWallCourse(courseId: id);
      deskSuccess = await _sender.openDeskCourse(courseId: id);
    } else {
      wallSuccess = await _sender.closeWallCourse(courseId: id);
      deskSuccess = await _sender.closeDeskCourse(courseId: id);
    }

    // 关键修复：主动同步 Handler 状态
    // 只有在关闭时才主动同步，开启时等待服务器反向通知
    if (!enabled) {
      _handler.wallCourseEnabled.value = false;
       _handler.deskCourseEnabled.value = false;
      wallEnabled = false;
       deskEnabled = false;
       wholeEnabled = false;
    }     
    if (wallSuccess && deskSuccess&& enabled) {
      wholeEnabled = enabled;
    } else if (!wallSuccess && !deskSuccess) {
      ToastUtils.show('墙面和桌面服务器均未连接',type: ToastType.error);
    } else if (!wallSuccess) {
      ToastUtils.show('墙面服务器未连接',type: ToastType.error);
    } else {
      ToastUtils.show('桌面服务器未连接',type: ToastType.error);  
    }

    update(['course_control_toggle']);
  }

  Future<void> setWallEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    bool success;
    if (enabled) {
      success = await _sender.openWallCourse(courseId: id);
    } else {
      success = await _sender.closeWallCourse(courseId: id);
    }

    if (!success) {
      ToastUtils.show('墙面服务器未连接',type: ToastType.error);
      return;
    }
    
    // 关键修复：主动同步 Handler 状态
    if (!enabled) {
      _handler.wallCourseEnabled.value = enabled;
      wallEnabled = enabled;
    }
    if (deskEnabled == enabled) {
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
  }

  Future<void> setDeskEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    bool success;
    if (enabled) {
      success = await _sender.openDeskCourse(courseId: id);
    } else {
      success = await _sender.closeDeskCourse(courseId: id);
    }

    if (!success) {
      ToastUtils.show('桌面服务器未连接',type: ToastType.error);
      return;
    }
    
    // 关键修复：主动同步 Handler 状态
    if (!enabled) {
      _handler.deskCourseEnabled.value = enabled;
      deskEnabled = enabled;
    }
    if (wallEnabled == enabled) {
      wholeEnabled = enabled;
    }
    update(['course_control_toggle']);
  }

  void setWallVolume(int value) {
    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  Future<void> commitWallVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);

    await _sender.setWallCourseVolume(volume: wallVolume);
  }

  void setDeskVolume(int value) {
    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  Future<void> commitDeskVolume(int value) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);

    await _sender.setDeskCourseVolume(volume: deskVolume);
  }

  @override
  void onClose() {
    // 移除所有 dispose 逻辑，因为此 Controller 为常驻单例，Worker 需要一直保持监听
    // 只有在 App 退出时才需要销毁，此时内存会自动回收
    super.onClose();
  }
}
