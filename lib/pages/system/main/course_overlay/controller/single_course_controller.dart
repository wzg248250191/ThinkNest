// ignore_for_file: unnecessary_null_comparison
import 'dart:async';

import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';
import 'package:think_nest/pages/index.dart';


class SingleCourseController extends GetxController {
  SingleCourseController();

  final PcCourseMessageHandler _handler = Get.find<PcCourseMessageHandler>();

  SocketService get _socketService => Get.find<SocketService>();

  String? courseId;

  int controlSelectedIndex = 0;

  bool wallEnabled = false;
  bool deskEnabled = false;
  bool wholeEnabled = false;
  int wallVolume = 100;
  int deskVolume = 100;

  Timer? _openCourseTimeoutTimer;
  int _openCourseTimeoutToken = 0;
  bool _expectWallEnable = false;
  bool _expectDeskEnable = false;

  bool get isWallConnected => _socketService.isConnected(ServerType.wall);

  bool get isDeskConnected => _socketService.isConnected(ServerType.desktop);

  String? get wallServerIp => _socketService.connectedServerIp(ServerType.wall).value;

  String? get deskServerIp => _socketService.connectedServerIp(ServerType.desktop).value;

  void _syncWholeEnabledFromParts() {
    if (!wholeEnabled) {
      if (wallEnabled && deskEnabled) {
        wholeEnabled = true;
      }
      return;
    }

    if (!wallEnabled && !deskEnabled) {
      wholeEnabled = false;
    }
  }

  /// 取消打开课程超时
  void _cancelOpenCourseTimeout() {
    _openCourseTimeoutTimer?.cancel();
    _openCourseTimeoutTimer = null;
    _expectWallEnable = false;
    _expectDeskEnable = false;
  }

  /// 启动打开课程超时
  void _startOpenCourseTimeout({
    required bool expectWallEnable,
    required bool expectDeskEnable,
  }) {
    _openCourseTimeoutToken++;
    final int token = _openCourseTimeoutToken;

    _openCourseTimeoutTimer?.cancel();
    _openCourseTimeoutTimer = null;

    _expectWallEnable = expectWallEnable;
    _expectDeskEnable = expectDeskEnable;

    _openCourseTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (token != _openCourseTimeoutToken) {
        return;
      }

      final bool wallOk =
          !_expectWallEnable || _handler.wallCourseEnabled.value == true;
      final bool deskOk =
          !_expectDeskEnable || _handler.deskCourseEnabled.value == true;
      if (wallOk && deskOk) {
        _cancelOpenCourseTimeout();
        return;
      }

      _cancelOpenCourseTimeout();
      ToastUtils.hide();    
      wallEnabled = _handler.wallCourseEnabled.value == true;
      deskEnabled = _handler.deskCourseEnabled.value == true;
      _syncWholeEnabledFromParts();
      update(['course_control_toggle', 'course_switches']);
    });
  }

  void _tryCompleteOpenCourseTimeout() {
    if (!_expectWallEnable && !_expectDeskEnable) {
      return;
    }

    if (_expectWallEnable && _handler.wallCourseEnabled.value != true) {
      return;
    }
    if (_expectDeskEnable && _handler.deskCourseEnabled.value != true) {
      return;
    }

    _cancelOpenCourseTimeout();
    ToastUtils.hide();
  }

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
          _cancelOpenCourseTimeout();
          ToastUtils.hide(force: true);

          final ServerType? type = _handler.lastStatusServerType.value;
          if (type == ServerType.wall) {
            setWallEnabled(false, skipConfirm: true);
          } else if (type == ServerType.desktop) {
            setDeskEnabled(false, skipConfirm: true);
          } else {
            setWallEnabled(false, skipConfirm: true);
            setDeskEnabled(false, skipConfirm: true);
          }
          ToastUtils.show(
            '课程已打开，正在关闭',
            duration: const Duration(seconds: 2),
          );
          return;
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
        _cancelOpenCourseTimeout();
        final info = _handler.lastStatusInfo.value;
        final fullMsg = (info != null && info.isNotEmpty) ? '$msg: $info' : msg;
        
        // 使用全屏 Dialog 弹窗
        ToastUtils.show(fullMsg, type: ToastType.error);
      }
    });

    ever<SocketState>(
      _socketService.connectionState(ServerType.wall),
      (_) {
        if (courseId != null) {
          update(['course_control_toggle']);
        }
      },
    );
    ever<SocketState>(
      _socketService.connectionState(ServerType.desktop),
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
      _syncWholeEnabledFromParts();
      _tryCompleteOpenCourseTimeout();
      update(['course_control_toggle', 'course_switches']);
    });

    ever<bool>(_handler.deskCourseEnabled, (enabled) {
      if (courseId == null) {
        return;
      }
      deskEnabled = enabled;
      _syncWholeEnabledFromParts();
      _tryCompleteOpenCourseTimeout();
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
    final bool isRunning =
        _handler.wallCourseEnabled.value == true || _handler.deskCourseEnabled.value == true;
    if (isRunning && _handler.currentCourseId.value == courseId) {
       this.courseId = courseId;
       
       // 同步 Handler 中的真实状态到 UI 变量
       wallEnabled = _handler.wallCourseEnabled.value;
       deskEnabled = _handler.deskCourseEnabled.value;
       _syncWholeEnabledFromParts();
       
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

    _cancelOpenCourseTimeout();
    ToastUtils.hide();
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

  /// 在指定端（墙面/桌面）开启课程
  ///
  /// 说明：
  /// - 若目标端未连接：触发 ensureConnected（历史 IP 直连 → UDP 扫描兜底 → 建连）
  /// - 连接成功后：发送开启课程指令
  Future<bool> _openCourseOn(
    ServerType serverType,
    String courseId, {
    bool ensureConnected = true,
  }) async {
    if (!_socketService.isConnected(serverType)) {
      if (!ensureConnected) {
        return false;
      }
      final connected = await _socketService.ensureConnected(serverType);
      if (!connected) {
        return false;
      }
    }
    if (!_socketService.isConnected(serverType)) {
      return false;
    }
    _socketService.controlApplication(serverType, courseId, true);
    return true;
  }

  /// 在指定端（墙面/桌面）关闭课程
  ///
  /// 说明：
  /// - 关闭时不触发连接/扫描逻辑（符合“关设备不做连接动作”的约束）
  Future<bool> _closeCourseOn(ServerType serverType, String courseId) async {
    if (!_socketService.isConnected(serverType)) {
      return true;
    }
    _socketService.controlApplication(serverType, courseId, false);
    return true;
  }

  Future<void> setWholeEnabled(bool enabled) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    if (enabled) {
      _cancelOpenCourseTimeout();
      final bool wallConnected = _socketService.isConnected(ServerType.wall);
      final bool deskConnected = _socketService.isConnected(ServerType.desktop);

      if (!wallConnected || !deskConnected) {
        if (!wallConnected && !deskConnected) {
          ToastUtils.show('墙面和桌面服务器均未连接', type: ToastType.error);
        } else if (!wallConnected) {
          ToastUtils.show('墙面服务器未连接', type: ToastType.error);
        } else {
          ToastUtils.show('桌面服务器未连接', type: ToastType.error);
        }
        update(['course_control_toggle']);
        return;
      }

      _socketService.controlApplication(ServerType.wall, id, true);
      _socketService.controlApplication(ServerType.desktop, id, true);

      ToastUtils.showLoading('课程正在打开中，请耐心等待');
      _startOpenCourseTimeout(expectWallEnable: true, expectDeskEnable: true);
      update(['course_control_toggle']);
      return;
    }

    _cancelOpenCourseTimeout();
    ToastUtils.hide();
    await _closeCourseOn(ServerType.wall, id);
    await _closeCourseOn(ServerType.desktop, id);

    _handler.wallCourseEnabled.value = false;
    _handler.deskCourseEnabled.value = false;
    wallEnabled = false;
    deskEnabled = false;
    wholeEnabled = false;
    update(['course_control_toggle']);
  }

  Future<void> setWallEnabled(bool enabled, {bool skipConfirm = false}) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }
    bool success;
    if (enabled) {
      _cancelOpenCourseTimeout();
      success = await _openCourseOn(ServerType.wall, id, ensureConnected: false);
    } else {
      if (!skipConfirm) {
        final bool confirmed = (await AlertDialog.show(
              '您确定要关闭课程吗？',
            )) ==
            true;
        if (!confirmed) {
          return;
        }
      }
      success = await _closeCourseOn(ServerType.wall, id);
    }

    if (!success) {
      _cancelOpenCourseTimeout();
      ToastUtils.show('墙面服务器未连接',type: ToastType.error);
      return;
    }
    
    // 关键修复：主动同步 Handler 状态
    if (!enabled) {
      _handler.wallCourseEnabled.value = enabled;
      wallEnabled = enabled;
    }
    _syncWholeEnabledFromParts();
    if (enabled) {
      ToastUtils.showLoading('课程正在打开中，请耐心等待');
      _startOpenCourseTimeout(expectWallEnable: true, expectDeskEnable: false);
    } else {
      _cancelOpenCourseTimeout();
      ToastUtils.hide();
    }
    update(['course_control_toggle']);
  }

  Future<void> setDeskEnabled(bool enabled, {bool skipConfirm = false}) async {
    final String? id = courseId;
    if (id == null) {
      return;
    }

    bool success;
    if (enabled) {
      _cancelOpenCourseTimeout();
      success = await _openCourseOn(ServerType.desktop, id, ensureConnected: false);
    } else {
      if (!skipConfirm) {
        final bool confirmed = (await AlertDialog.show(
              '您确定要关闭课程吗？',
            )) ==
            true;
        if (!confirmed) {
          return;
        }
      }
      success = await _closeCourseOn(ServerType.desktop, id);
    }

    if (!success) {
      _cancelOpenCourseTimeout();
      ToastUtils.show('桌面服务器未连接',type: ToastType.error);
      return;
    }
    if (enabled) {
      ToastUtils.showLoading('课程正在打开中，请耐心等待');
      _startOpenCourseTimeout(expectWallEnable: false, expectDeskEnable: true);
    } else {
      _cancelOpenCourseTimeout();
      ToastUtils.hide();
    }
    // 关键修复：主动同步 Handler 状态
    if (!enabled) {
      _handler.deskCourseEnabled.value = enabled;
      deskEnabled = enabled;
    }
    _syncWholeEnabledFromParts();
    update(['course_control_toggle']);
  }

  void setWallVolume(int value) {
    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  Future<void> commitWallVolume(int value) async {
    if (courseId == null) {
      return;
    }

    wallVolume = value.clamp(0, 100);
    update(['volume_slider']);

    if (_socketService.isConnected(ServerType.wall)) {
      _socketService.setVolume(ServerType.wall, wallVolume);
    }
  }

  void setDeskVolume(int value) {
    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);
  }

  Future<void> commitDeskVolume(int value) async {
    if (courseId == null) {
      return;
    }

    deskVolume = value.clamp(0, 100);
    update(['volume_slider']);

    if (_socketService.isConnected(ServerType.desktop)) {
      _socketService.setVolume(ServerType.desktop, deskVolume);
    }
  }

  @override
  void onClose() {
    // 移除所有 dispose 逻辑，因为此 Controller 为常驻单例，Worker 需要一直保持监听
    // 只有在 App 退出时才需要销毁，此时内存会自动回收
    _cancelOpenCourseTimeout();
    super.onClose();
  }
}
