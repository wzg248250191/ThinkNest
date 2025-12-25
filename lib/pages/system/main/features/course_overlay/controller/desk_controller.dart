import 'package:get/get.dart';

import '../../../../../../common/index.dart';
import '../data/single_course_command_sender.dart';
import 'single_course_controller.dart';

class DeskController extends GetxController {
  DeskController();

  final PcCourseCommandSender _sender = Get.find<PcCourseCommandSender>();
  final SingleCourseController _courseController = Get.find<SingleCourseController>();

  bool isTesting = false;

  Future<void> onPlayTap(bool v) async {
    if (_courseController.courseId == null) {
      ToastUtils.show('请先选择课程');
      return;
    }
    if (!_courseController.isDeskConnected) {
      ToastUtils.show('桌面服务器未连接');
      return;
    }
    if (!_courseController.deskEnabled) {
      ToastUtils.show('请先开启桌面课程');
      return;
    }

    final bool success = await _sender.startDeskGame(v);
    if (!success) {
      ToastUtils.show('桌面服务器未连接');
      return;
    }

    isTesting = v;
    update(['desk_part']);
  }
}
