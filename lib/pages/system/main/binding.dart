import 'package:get/get.dart';

import 'package:think_nest/pages/index.dart';

/// 主界面依赖
class MainBinding implements Bindings {
  @override
  void dependencies() {
    // 依赖注入保持幂等：避免从启动页/其它入口提前注册后，重复注册引发异常
    if (!Get.isRegistered<PcCourseMessageHandler>()) {
      Get.lazyPut<PcCourseMessageHandler>(() => PcCourseMessageHandler());
    }
    if (!Get.isRegistered<CourseController>()) {
      Get.lazyPut<CourseController>(() => CourseController());
    }

    // 改为 put 并设置 permanent: true，使其常驻内存，支持后台状态保持和悬浮窗功能
    if (!Get.isRegistered<SingleCourseController>()) {
      Get.put<SingleCourseController>(SingleCourseController(), permanent: true);
    }
    if (!Get.isRegistered<DeskController>()) {
      Get.put<DeskController>(DeskController(), permanent: true);
    }
    if (!Get.isRegistered<WallController>()) {
      Get.put<WallController>(WallController(), permanent: true);
    }

    if (!Get.isRegistered<IntegrationController>()) {
      Get.lazyPut<IntegrationController>(() => IntegrationController());
    }
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut<SettingsController>(() => SettingsController());
    }
    if (!Get.isRegistered<MainController>()) {
      Get.lazyPut<MainController>(() => MainController());
    }
  }
}
