import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 配置服务
class ConfigService extends GetxService {
  // 这是一个单例写法
  static ConfigService get to => Get.find();

  // 包信息
  PackageInfo? _platform;

  // 版本号
  String get version => _platform?.version ?? '-';
  // 主题
  AdaptiveThemeMode themeMode = AdaptiveThemeMode.light;

   // 初始化
  Future<ConfigService> init() async {
    await getPlatform();
    await initTheme();
    //initLocale();
    return this;
  }


  // 获取包信息
  Future<void> getPlatform() async {
    _platform = await PackageInfo.fromPlatform();
  }

    // 初始 theme
  Future<void> initTheme() async {
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    themeMode = savedThemeMode ?? AdaptiveThemeMode.light;
  }

    // 切换 theme
  Future<void> setThemeMode(String themeKey) async {
    switch (themeKey) {
      case "light":
        AdaptiveTheme.of(Get.context!).setLight();
        break;
      case "dark":
        AdaptiveTheme.of(Get.context!).setDark();
        break;
      case "system":
        AdaptiveTheme.of(Get.context!).setSystem();
        break;
    }
  }
}
