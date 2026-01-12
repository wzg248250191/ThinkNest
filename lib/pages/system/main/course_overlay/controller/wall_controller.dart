import 'package:get/get.dart';

import '../../../../../../common/index.dart';
import '../data/course_net_operation_table.dart';
import '../data/pc_course_message_handler.dart';
import 'single_course_controller.dart';

enum WallArea {
  left,
  middle,
  right,
}

class WallController extends GetxController {
  WallController();

  final SingleCourseController _courseController = Get.find<SingleCourseController>();
  final PcCourseMessageHandler _handler = Get.find<PcCourseMessageHandler>();
  SocketService get _socketService => Get.find<SocketService>();

  // 墙面开关状态
  final RxBool leftPower = false.obs;
  final RxBool midPower = false.obs;
  final RxBool rightPower = false.obs;

  // 墙面互动状态
  final RxBool leftInteract = false.obs;
  final RxBool midInteract = false.obs;
  final RxBool rightInteract = false.obs;

  /// 重置墙面操作面板状态为默认值
  void resetPanelState() {
    leftPower.value = false;
    midPower.value = false;
    rightPower.value = false;

    leftInteract.value = false;
    midInteract.value = false;
    rightInteract.value = false;
  }

  Future<void> onWallPowerChanged(WallArea area, bool enabled) async {
    if (_courseController.courseId == null) {
      ToastUtils.show('请先选择课程');
      return;
    }
    if (!_courseController.isWallConnected) {
      ToastUtils.show('墙面服务器未连接');
      return;
    }
    if (!_courseController.wallEnabled) {
      ToastUtils.show('请先开启墙面课程');
      return;
    }

    // 更新本地状态
    _updatePowerState(area, enabled);
    
    // 如果是双控模式，且操作的是左右墙面，同步更新另一侧状态（但不发送指令）
    if (_handler.isWallDoubleControl.value) {
      if (area == WallArea.left) {
        rightPower.value = enabled;
      } else if (area == WallArea.right) {
        leftPower.value = enabled;
      }
    }

    final bool success = await _sendWallPower(area, enabled);
    if (!success) {
      ToastUtils.show('墙面服务器未连接');
      // 如果发送失败，回滚状态
      _updatePowerState(area, !enabled);
       if (_handler.isWallDoubleControl.value) {
        if (area == WallArea.left) {
          rightPower.value = !enabled;
        } else if (area == WallArea.right) {
          leftPower.value = !enabled;
        }
      }
    }
  }

  void _updatePowerState(WallArea area, bool enabled) {
    switch (area) {
      case WallArea.left:
        leftPower.value = enabled;
        break;
      case WallArea.middle:
        midPower.value = enabled;
        break;
      case WallArea.right:
        rightPower.value = enabled;
        break;
    }
  }

  Future<void> onWallInteractChanged(WallArea area, bool enabled) async {
    if (_courseController.courseId == null) {
      ToastUtils.show('请先选择课程');
      return;
    }
    if (!_courseController.isWallConnected) {
      ToastUtils.show('墙面服务器未连接');
      return;
    }
    if (!_courseController.wallEnabled) {
      ToastUtils.show('请先开启墙面课程');
      return;
    }

    // 更新本地状态
    _updateInteractState(area, enabled);

    // 如果是双控模式，且操作的是左右墙面，同步更新另一侧状态（但不发送指令）
    if (_handler.isWallDoubleControl.value) {
      if (area == WallArea.left) {
        rightInteract.value = enabled;
      } else if (area == WallArea.right) {
        leftInteract.value = enabled;
      }
    }

    final bool success = await _sendWallInteract(area, enabled);
    if (!success) {
      ToastUtils.show('墙面服务器未连接');
      // 回滚
      _updateInteractState(area, !enabled);
       if (_handler.isWallDoubleControl.value) {
        if (area == WallArea.left) {
          rightInteract.value = !enabled;
        } else if (area == WallArea.right) {
          leftInteract.value = !enabled;
        }
      }
    }
  }

  void _updateInteractState(WallArea area, bool enabled) {
    switch (area) {
      case WallArea.left:
        leftInteract.value = enabled;
        break;
      case WallArea.middle:
        midInteract.value = enabled;
        break;
      case WallArea.right:
        rightInteract.value = enabled;
        break;
    }
  }

  Future<void> onWallRestartTap(WallArea area) async {
    if (_courseController.courseId == null) {
      ToastUtils.show('请先选择课程');
      return;
    }
    if (!_courseController.isWallConnected) {
      ToastUtils.show('墙面服务器未连接');
      return;
    }
    if (!_courseController.wallEnabled) {
      ToastUtils.show('请先开启墙面课程');
      return;
    }

    // 关键逻辑：点击“重新启动”时先将“关闭墙面/关闭互动”回到默认状态，避免重启后 UI 保留旧的关闭态。
    _updatePowerState(area, false);
    _updateInteractState(area, false);
    if (_handler.isWallDoubleControl.value) {
      // 关键逻辑：双控模式下左右墙面状态联动显示；重启任一侧时同步复位另一侧，避免 UI 不一致。
      if (area == WallArea.left) {
        rightPower.value = false;
        rightInteract.value = false;
      } else if (area == WallArea.right) {
        leftPower.value = false;
        leftInteract.value = false;
      }
    }

    final bool success = await _sendWallRestart(area);
    if (!success) {
      ToastUtils.show('墙面服务器未连接');
      return;
    }

    // 关键逻辑：重启后补发“开启互动”指令，确保墙面互动区默认处于开启状态。
    final bool interactOpened = await _sendWallInteract(area, false);
    if (!interactOpened) {
      ToastUtils.show('墙面服务器未连接');
    }
  }

  Future<bool> _sendWallPower(WallArea area, bool enabled) {
    if (!_socketService.isConnected(ServerType.wall)) {
      return Future.value(false);
    }
    final String op = switch (area) {
      WallArea.left =>
        enabled ? CourseNetOperationTable.wallLPause.code : CourseNetOperationTable.wallLPlay.code,
      WallArea.middle =>
        enabled ? CourseNetOperationTable.wallMPause.code : CourseNetOperationTable.wallMPlay.code,
      WallArea.right =>
        enabled ? CourseNetOperationTable.wallRPause.code : CourseNetOperationTable.wallRPlay.code,
    };
    _socketService.sendUnityOperation(ServerType.wall, op);
    return Future.value(true);
  }

  Future<bool> _sendWallInteract(WallArea area, bool enabled) {
    if (!_socketService.isConnected(ServerType.wall)) {
      return Future.value(false);
    }
    final String op = switch (area) {
      WallArea.left =>
        enabled ? CourseNetOperationTable.wallLClose.code : CourseNetOperationTable.wallLOpen.code,
      WallArea.middle =>
        enabled ? CourseNetOperationTable.wallMClose.code : CourseNetOperationTable.wallMOpen.code,
      WallArea.right =>
        enabled ? CourseNetOperationTable.wallRClose.code : CourseNetOperationTable.wallROpen.code,
    };
    _socketService.sendUnityOperation(ServerType.wall, op);
    return Future.value(true);
  }

  Future<bool> _sendWallRestart(WallArea area) {
    if (!_socketService.isConnected(ServerType.wall)) {
      return Future.value(false);
    }
    final String op = switch (area) {
      WallArea.left => CourseNetOperationTable.wallLRestart.code,
      WallArea.middle => CourseNetOperationTable.wallMRestart.code,
      WallArea.right => CourseNetOperationTable.wallRRestart.code,
    };
    _socketService.sendUnityOperation(ServerType.wall, op);
    return Future.value(true);
  }
}
