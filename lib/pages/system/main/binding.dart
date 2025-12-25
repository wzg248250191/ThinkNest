import 'package:get/get.dart';

import '../../index.dart';

/// 主界面依赖
class MainBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PcCourseCommandSender>(() => PcCourseCommandSender());
    Get.lazyPut<PcCourseMessageHandler>(() => PcCourseMessageHandler());
    Get.lazyPut<CourseController>(() => CourseController());
    // 改为 put 并设置 permanent: true，使其常驻内存，支持后台状态保持和悬浮窗功能
    Get.put<SingleCourseController>(SingleCourseController(), permanent: true);
    Get.put<DeskController>(DeskController(), permanent: true);
    Get.put<WallController>(WallController(), permanent: true);
    Get.lazyPut<IntegrationController>(() => IntegrationController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<MainController>(() => MainController());
  }
}
