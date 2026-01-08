import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../common/index.dart';
import '../../index.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  /// 构建主页面并保持页面状态不被回收
  Widget build(BuildContext context) {
    super.build(context);
    return const _MainViewGetX();
  }
}

class _MainViewGetX extends GetView<MainController> {
  const _MainViewGetX();

  /// 构建惰性 Tab 内容容器，避免首次进入时一次性构建所有页面
  Widget _buildLazyContent() {
    // 注意：这里不能使用 const，否则 GetBuilder 刷新时子树可能不 rebuild；
    // 同时固定 key，确保每次 rebuild 都复用同一个 State，避免切页时丢失缓存页面与出现闪烁
    return _MainLazyTabBody(key: const ValueKey('main_lazy_tab_body'));
  }

  // 主视图
  /// 构建主页面内容与全屏课程覆盖层，并处理返回键逻辑
  Widget _buildView(BuildContext context) {
    return PopScope(
      // 允许返回
      canPop: false,

      // 防止连续点击两次退出
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // 如果返回，则不执行退出请求
        if (didPop) {
          return;
        }

        if (controller.showCourseDetail) {
          controller.closeCourseController();
          return;
        }

        // 退出请求
        if (controller.closeOnConfirm(context)) {
          SystemNavigator.pop(); // 系统级别导航栈 退出程序
        }
      },

      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        // 内容页
        body: Stack(
          children: [
           <Widget>[
          <Widget>[
             ImageWidget.img(
              AssetsImages.logoPng,
              width: 107.84.w,
              height: 120.99.h,
            ).paddingTop(60.h),
             GetBuilder<MainController>(
                      id: 'navigation',
                      builder: (controller) {
                        return BuildNavigation(
                          currentIndex: controller.currentIndex,
                          selectedScale: 1.3,
                          defaultFontSize: 28,
                          defaultFontWeight: FontWeight.w400,
                          items: [
                            NavigationItemModel(
                              label: "开始上课",                            
                              icon: AssetsSvgs.navStartSvg,
                              iconWidth: 52.2,
                              iconHeight: 50.27,  
                              itemHeight: 250.w                         
                            ),
                            NavigationItemModel(
                              label: "一体化",                            
                              icon: AssetsSvgs.navIntegratedSvg,
                              iconWidth: 52.44,
                              iconHeight: 52.41,
                              itemHeight: 250.w
                            ),
                            NavigationItemModel(
                              label: "设置",                            
                              icon: AssetsSvgs.navSettingsSvg,
                              iconWidth: 50.28,
                              iconHeight: 47.52,
                              itemHeight:250.w
                            )
                          ],
                          onTap: controller.onJumpToPage,
                        );
                      },
                    ).expanded()
          ].toColumn()
              .width(240.w)
              // 右侧分隔边框：与右侧内容区域做视觉分隔
              .decorated(
                border: Border(
                  right: BorderSide(
                    color: context.colors.scheme.outline,
                    width: AppBorder.card,
                  ),
                ),
              )
              .backgroundColor(CustomAppColors.card),
         // 右侧渐变阴影条：增强阴影可见性（深->浅）
            Container(
              width: 3.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Expanded(//导航栏右侧内容
            child: GetBuilder<MainController>(
              id: 'content',
              builder: (_) {
                return _buildLazyContent();
              },
            ),
          )
        ].toRow(),
        GetBuilder<MainController>(
          id: 'main_overlay',
          builder: (_) {
            final bool visible = controller.showCourseDetail;
            return Positioned.fill(
              child: Offstage(
                offstage: !visible,
                child: TickerMode(
                  enabled: visible,
                  child: const CourseDetailOverlay(),
                ),
              ),
            );
          },
        ),
        // 启动遮罩：在主页面已构建但课程页仍在预热时遮挡住画面
        GetBuilder<MainController>(
          id: 'startup_splash',
          builder: (_) {
            final bool visible = controller.showStartupSplashOverlay;
            return Positioned.fill(
              child: Offstage(
                offstage: !visible,
                child: AbsorbPointer(
                  absorbing: true,
                  child: const ColoredBox(
                    // 先绘制纯色底，避免首帧图片尚未解码时露出主界面
                    color: Colors.white,
                    child: ImageWidget.img(
                      AssetsImages.splashPng,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ]
      )
      ),
    );
  }


  @override
   /// GetX 驱动的主页面入口
   Widget build(BuildContext context) {
   return GetBuilder<MainController>(
      id: "main",
      builder: (_) {
        return _buildView(context);
      },
    );
  }
}

/// 主界面右侧内容区：按需构建 Tab 页面并缓存，减少首屏卡顿
class _MainLazyTabBody extends StatefulWidget {
  /// [key] 用于让父级在 rebuild 时复用同一个 State（避免切页闪烁与缓存丢失）
  const _MainLazyTabBody({super.key});

  @override
  State<_MainLazyTabBody> createState() => _MainLazyTabBodyState();
}

class _MainLazyTabBodyState extends State<_MainLazyTabBody> {
  final List<Widget?> _pages = List<Widget?>.filled(3, null);
  bool _isUiReady = false;

  /// 根据索引创建对应页面实例
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const CoursePage();
      case 1:
        return const IntegrationPage();
      case 2:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    // 策略调整：首屏只渲染左侧导航与 Logo，右侧内容延后加载，
    // 避免 CoursePage 控制器初始化/图片解码在“进入界面瞬间”阻塞动画。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isUiReady = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
    final int index = controller.currentIndex.clamp(0, _pages.length - 1);
    if (_isUiReady) {
      _pages[index] ??= _buildPage(index);
      // 启动遮罩可见期间：额外预热课程页（即使当前在一体化/设置页，也会在遮罩下完成构建）
      if (controller.showStartupSplashOverlay) {
        _pages[0] ??= _buildPage(0);
      }
    }

    if (!_isUiReady) {
      // 首屏占位：保证脉冲动画与导航交互优先顺畅
      return Center(
        child: <Widget>[
          PulseDot(
            size: 18.w,
            color: CustomAppColors.primary,
          ),
          SizedBox(height: 16.h),
          PulseDot(
            size: 18.w,
            color: CustomAppColors.primary,
          ),
          SizedBox(height: 18.h),
          TextWidget.label(
            '正在加载…',
            fontSize: 28.sp,
            color: CustomAppColors.subText,
          ),
        ].toColumn(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      );
    }

    return IndexedStack(
      index: index,
      children: <Widget>[
        _pages[0] ?? const SizedBox.shrink(),
        _pages[1] ?? const SizedBox.shrink(),
        _pages[2] ?? const SizedBox.shrink(),
      ],
    );
  }
}
