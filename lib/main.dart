import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:think_nest/global.dart';

import 'common/index.dart';

void main() async {
  await Global.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 设置全屏沉浸式布局，让app内容延伸到状态栏和导航栏区域
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    // 设置状态栏样式为透明，悬浮在app上
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 状态栏背景透明
        statusBarIconBrightness: Brightness.dark, // 状态栏图标为深色（亮色背景时使用）
        statusBarBrightness: Brightness.light, // iOS状态栏样式
        systemNavigationBarColor: Colors.black, // 导航栏颜色
        systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标亮度
      ),
    );
  }

  // This widget is the root of your application.
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
          title: 'Flutter Demo',

          // 主题
          theme: theme,
          darkTheme: darkTheme,

          // 路由
          initialRoute: RouteNames.systemMain,
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


