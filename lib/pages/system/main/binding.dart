import 'package:get/get.dart';

import '../../index.dart';
import '../../../common/index.dart';

/// 主界面依赖
class MainBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommandChannelService>(() => CommandChannelService()..init());
    Get.lazyPut<SingleCourseCommandRepository>(() => SingleCourseCommandRepository());
    Get.lazyPut<CourseController>(() => CourseController());
    Get.lazyPut<SingleCourseController>(() => SingleCourseController());
    Get.lazyPut<IntegrationController>(() => IntegrationController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<MainController>(() => MainController());
  }
}
