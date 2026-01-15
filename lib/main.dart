import 'dart:async';
import 'dart:ui';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:think_nest/global.dart';

import 'common/index.dart';

/// 应用启动入口
///
/// 说明：
/// - 先确保 Flutter 引擎/插件绑定完成，再进行全局初始化
/// - 在 runApp 前完成横屏锁定与沉浸式/状态栏样式配置，避免首帧 UI 抖动
Future<void> main() async {
  DebugUtils.log("------------程序启动------------", name: 'global');
  runZonedGuarded(
    () async {
      // 关键：确保绑定初始化与 runApp 在同一个 Zone 内，避免 Zone mismatch
      final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      // 保留 Native Splash 直到自定义启动图资源就绪，避免中间出现“纯白过渡帧”
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
      await Global.init();

      // 关键：统一拦截运行时错误并落盘，便于现场回溯问题（不依赖控制台输出）
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        AppLogService.tryRecordError(
          details.exception,
          details.stack ?? StackTrace.current,
          tag: 'flutter',
        );
      };

      // 关键：捕获平台派发的未处理异常（Flutter 3+ 推荐路径）
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLogService.tryRecordError(error, stack, tag: 'platform');
        return false;
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);

      // 设置沉浸式布局：让内容延伸到状态栏/导航栏区域
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      // 统一配置系统 UI 样式：首帧前设置可减少闪烁与二次布局
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      // 关键：兜底捕获 Zone 内未处理异常，避免“异步异常丢失”导致无法排查
      AppLogService.tryRecordError(error, stack, tag: 'zone');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        // 关键：将所有 print 输出统一落盘为“打印日志”
        AppLogService.tryRecordPrint(line, tag: 'print');
      },
    ),
  );
}

/// 应用根组件
///
/// 说明：
/// - 作为全局主题/路由/适配的容器，本身不持有状态，使用 StatelessWidget 更轻量
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(2000, 1200), // 设计稿中设备的尺寸(单位随意,建议dp,但在使用过程中必须保持一致)
      splitScreenMode: false, // 支持分屏尺寸
      minTextAdapt: false, // 是否根据宽度/高度中的最小值适配文字

      // 构建
      builder: (context, child) => AdaptiveTheme(
        // 样式
        light: AppTheme.custom, // 默认使用自定义主题作为亮色模式
        dark: AppTheme.dark, // 暗色主题
        initial: ConfigService.to.themeMode, // 初始主题
        debugShowFloatingThemeButton: false, // 显示主题按钮

        // 构建
        builder: (theme, darkTheme) => GetMaterialApp(
          title: '成长之光',

          // 主题
          theme: theme,
          darkTheme: darkTheme,

          // 路由
          // 关键逻辑：启动先进入自定义 SplashPage，让 Native Splash 尽快移除，
          // 后续在 Flutter Splash 期间完成预加载，减少“原生启动图停留过久”的体感。
          initialRoute: RouteNames.systemSplash,
          getPages: RoutePages.list,
          navigatorObservers: [RoutePages.observer],

          // 多语言
          //translations: Translation(), // 词典
         // localizationsDelegates: Translation.localizationsDelegates, // 代理
         // supportedLocales: Translation.supportedLocales, // 支持的语言种类
          //locale: ConfigService.to.locale, // 当前语言种类
         // fallbackLocale: Translation.fallbackLocale, // 默认语言种类

          // builder
          builder: (context, widget) {
            final data = MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0));
            return MediaQuery(
              data: data,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget!,
              ),
            );
          },

          // 隐藏 debug 标志
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
