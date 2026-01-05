import 'package:get/get.dart';

import '../../../../../../common/index.dart';
import '../data/course_net_operation_table.dart';
import 'single_course_controller.dart';

class DeskController extends GetxController {
  DeskController();

  final SingleCourseController _courseController = Get.find<SingleCourseController>();
  SocketService get _socketService => Get.find<SocketService>();

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

    final bool success = await _startDeskGame(v);
    if (!success) {
      ToastUtils.show('桌面服务器未连接');
      return;
    }

    isTesting = v;
    update(['desk_part']);
  }

  Future<bool> _startDeskGame(bool isOn) async {
    if (!_socketService.isConnected(ServerType.desktop)) {
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.desktop,
      isOn ? CourseNetOperationTable.deskPlayTest.code : CourseNetOperationTable.deskTestOver.code,
    );
    return true;
  }
}
