
import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../pages/index.dart';
import '../index.dart';

class RoutePages {
  // 历史记录
  static final List<String> history = <String>[];
   // 观察者
  static final RouteObservers observer = RouteObservers();
  static bool _routesValidated = false;

  static Bindings _safeBinding(void Function() register) {
    return BindingsBuilder(() {
      register();
    });
  }

  /// 校验路由表配置的基本正确性（仅在 Debug 下执行）
  ///
  /// 说明：
  /// - 防止路由名重复导致跳转行为不确定
  /// - 防止未以 '/' 开头的路由名在 GetX 下行为异常
  static void _validateRoutesIfNeeded(List<GetPage<dynamic>> pages) {
    if (_routesValidated) return;
    _routesValidated = true;

    assert(() {
      final Map<String, int> counter = <String, int>{};
      for (final page in pages) {
        final name = page.name;
        if (!name.startsWith('/')) {
          throw FlutterError('路由名必须以 "/" 开头：$name');
        }
        counter[name] = (counter[name] ?? 0) + 1;
      }

      final duplicates = counter.entries.where((e) => e.value > 1).toList();
      if (duplicates.isNotEmpty) {
        final detail = duplicates.map((e) => '${e.key} x${e.value}').join(', ');
        throw FlutterError('发现重复路由名：$detail');
      }
      return true;
    }());
  }

  static void _ensureCourseDependencies() {
    if (!Get.isRegistered<CourseController>()) {
      Get.lazyPut<CourseController>(() => CourseController());
    }
  }

  static void _ensureIntegrationDependencies() {
    if (!Get.isRegistered<IntegrationController>()) {
      Get.lazyPut<IntegrationController>(() => IntegrationController());
    }
  }

  static void _ensureSettingsDependencies() {
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut<SettingsController>(() => SettingsController());
    }
  }
  // 列表
  static final List<GetPage> _list = [
    GetPage(
        name: RouteNames.course,
        page: () => const CoursePage(),
        binding: _safeBinding(_ensureCourseDependencies),
      ),
      GetPage(
        name: RouteNames.integration,
        page: () => const IntegrationPage(),
        binding: _safeBinding(_ensureIntegrationDependencies),
      ),
      GetPage(
        name: RouteNames.settings,
        page: () => const SettingsPage(),
        binding: _safeBinding(_ensureSettingsDependencies),
      ),
      GetPage(
        name: RouteNames.systemMain,
        page: () => const MainPage(),
        binding: MainBinding(), // 绑定 MainPage 所需依赖
      ),
       GetPage(
        name: RouteNames.systemSplash,
        page: () => const SplashPage(),
        // SplashPage 内部通过 GetBuilder(init: SplashController()) 自行创建控制器；
        // 此处不绑定 MainBinding，避免启动页阶段提前注册大量依赖且与 CourseController 的 permanent 注册产生冲突风险。
      ),
   ];

  static List<GetPage> get list {
    _validateRoutesIfNeeded(_list);
    return _list;
  }
}
