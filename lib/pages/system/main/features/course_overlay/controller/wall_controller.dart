import 'package:get/get.dart';

import '../../../../../../common/index.dart';
import '../data/single_course_command_sender.dart';
import '../data/pc_course_message_handler.dart';
import 'single_course_controller.dart';

enum WallArea {
  left,
  middle,
  right,
}

class WallController extends GetxController {
  WallController();

  final PcCourseCommandSender _sender = Get.find<PcCourseCommandSender>();
  final SingleCourseController _courseController = Get.find<SingleCourseController>();
  final PcCourseMessageHandler _handler = Get.find<PcCourseMessageHandler>();

  // 墙面开关状态
  final RxBool leftPower = false.obs;
  final RxBool midPower = false.obs;
  final RxBool rightPower = false.obs;

  // 墙面互动状态
  final RxBool leftInteract = false.obs;
  final RxBool midInteract = false.obs;
  final RxBool rightInteract = false.obs;

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

    final bool success = await _sendWallRestart(area);
    if (!success) {
      ToastUtils.show('墙面服务器未连接');
    }
  }

  Future<bool> _sendWallPower(WallArea area, bool enabled) {
    switch (area) {
      case WallArea.left:
        return _sender.leftWallOpenOrClose(enabled);
      case WallArea.middle:
        return _sender.midWallOpenOrClose(enabled);
      case WallArea.right:
        return _sender.rightWallOpenOrClose(enabled);
    }
  }

  Future<bool> _sendWallInteract(WallArea area, bool enabled) {
    switch (area) {
      case WallArea.left:
        return _sender.leftWallEnbale(enabled);
      case WallArea.middle:
        return _sender.midWallEnbale(enabled);
      case WallArea.right:
        return _sender.rightWallEnbale(enabled);
    }
  }

  Future<bool> _sendWallRestart(WallArea area) {
    switch (area) {
      case WallArea.left:
        return _sender.leftWallRestart();
      case WallArea.middle:
        return _sender.midWallRestart();
      case WallArea.right:
        return _sender.rightWallRestart();
    }
  }
}
