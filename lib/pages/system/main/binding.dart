import 'package:get/get.dart';

import '../../index.dart';

/// 主界面依赖
class MainBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CourseController>(() => CourseController());
    Get.lazyPut<IntegrationController>(() => IntegrationController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<MainController>(() => MainController());
  }
}
