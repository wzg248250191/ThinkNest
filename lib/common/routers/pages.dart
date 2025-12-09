
import 'package:get/get.dart';

import '../../pages/index.dart';
import '../index.dart';

class RoutePages {
  // 列表
   static List<GetPage> list = [
    GetPage(
        name: RouteNames.course,
        page: () => const CoursePage(),
      ),
      GetPage(
        name: RouteNames.integration,
        page: () => const IntegrationPage(),
      ),
      GetPage(
        name: RouteNames.settings,
        page: () => const SettingsPage(),
      ),
      GetPage(
        name: RouteNames.systemMain,
        page: () => const MainPage(),
      ),
   ];
}
