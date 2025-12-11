import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../index.dart'; // 确保导入了 AppTheme 所在的 index.dart

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
    // 默认使用 light，如果你想默认使用 custom，需要配合 AdaptiveTheme 的设置
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
      // 添加自定义主题切换逻辑
      // 注意：AdaptiveTheme 默认只支持 light/dark/system。
      // 如果要使用 custom 主题，通常的做法是把它作为 'light' 或 'dark' 的一种变体传入，或者替换掉其中一个。
      // 但在这里，既然我们在 theme.dart 里定义了 custom，
      // 最简单的方法是：让 'custom' 这个 key 对应设置为 theme.dart 里的 AppTheme.custom
      case "custom":
        // 由于 AdaptiveTheme 核心只管理 light/dark，如果要设置第三种主题，
        // 我们通常是调用 setTheme 并传入具体的 ThemeData
        // 但 AdaptiveTheme 3.x+ 主要支持 setLight/setDark/setSystem
        
        // 如果你的意图是把 "custom" 当作默认的亮色主题来用：
        AdaptiveTheme.of(Get.context!).setTheme(
          light: AppTheme.custom, // 将 custom 设置为当前使用的 light 主题
          dark: AppTheme.dark,    // 保持 dark 主题不变
        );
        // 或者强制切换到 light 模式（此时 light 已经被替换为 custom）
        AdaptiveTheme.of(Get.context!).setLight();
        break;
    }
  }
}
