import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';
import 'package:think_nest/pages/index.dart';

class MainController extends GetxController {
  // 当前的 tab index
  int currentIndex = 0;

  /// 启动遮罩是否可见（用于“完全热启动”预热）
  bool _showStartupSplashOverlay = true;

  /// 对外暴露：启动遮罩是否可见
  bool get showStartupSplashOverlay => _showStartupSplashOverlay;

  // 退出请求时间
  DateTime? currentBackPressTime;

  /// 初始化主页面数据并触发首次刷新
  void _initData() {
    update(["main"]);
  }

  /// 启动期“完全热启动”预热：
  /// 1）开启课程页全量构建模式；
  /// 2）等待课程清单并预缓存图片；
  /// 3）在启动遮罩下完成课程页首帧构建；
  /// 4）预热完成后揭开遮罩。
  Future<void> _warmStart() async {
    if (!_showStartupSplashOverlay) {
      return;
    }

    // 先让主界面至少绘制一帧，确保遮罩已显示
    await WidgetsBinding.instance.endOfFrame;

    // 课程页预热：开启全量构建模式 + 预缓存资源
    final CourseController courseController = Get.find<CourseController>();
    courseController.enableFullBuildAllMode();
    await courseController.preloadForSplash();

    // 触发一次内容区刷新，让课程页在遮罩下完成构建与布局
    update(['content']);

    // 等待若干帧，确保课程页至少完成一次 build/layout/paint
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    _showStartupSplashOverlay = false;
    update(['startup_splash']);
  }

  // 导航栏切换
  /// 切换左侧导航栏高亮与右侧内容页
  void onIndexChanged(int index) {
    currentIndex = index;
    update(['content', 'navigation']);
  }

  // 切换页面
  /// 点击导航项跳转到对应页面
  void onJumpToPage(int page) {
    currentIndex = page;
    update(['content', 'navigation']);
  }

  // 返回键退出
  /// 处理系统返回键二次确认退出逻辑
  bool closeOnConfirm(BuildContext context) {
    DateTime now = DateTime.now();
    // 物理键，两次间隔大于4秒, 退出请求无效
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) > const Duration(seconds: 4)) {
      currentBackPressTime = now;
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.only(bottom: 24.h),
            padding: EdgeInsets.zero,
            duration: const Duration(seconds: 2),
            content: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: scheme.onInverseSurface.withValues(alpha: 0.10),
                    width: 1.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12.r,
                      offset: Offset(0, 6.h),
                    ),
                  ],
                ),
                child: TextWidget.label(
                  '再按一次退出应用',
                  fontSize: 24.sp,
                  color: scheme.onInverseSurface,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      return false;
    }

    // 退出请求有效
    currentBackPressTime = null;
    return true;
  }

  /// 课程详情覆盖层是否展示
  bool showCourseDetail = false;

  /// 打开全屏课程详情覆盖层，并保证停留在课程 tab
  void openCourseController(String name) {
    // 关键保护：避免在 Binding 尚未执行时 Get.find 直接抛错导致崩溃
    final PcCourseMessageHandler? handler =
        Get.isRegistered<PcCourseMessageHandler>() ? Get.find<PcCourseMessageHandler>() : null;
    if (handler == null) {
      ToastUtils.show('系统尚未初始化，请稍后重试');
      return;
    }
    // 关键保护：复用同一个 Controller 实例，避免重复 Get.find，并防止未注册时直接抛错
    final SingleCourseController? singleCourseController =
        Get.isRegistered<SingleCourseController>() ? Get.find<SingleCourseController>() : null;
    if (singleCourseController == null) {
      ToastUtils.show('课程控制器尚未初始化，请稍后重试');
      return;
    }
    final activeId = handler.currentCourseId.value;
    final isRunning = handler.wallCourseEnabled.value || handler.deskCourseEnabled.value;

    // 互斥拦截逻辑
    // 1. 如果当前有课程在运行
    // 2. 且点击的课程不是当前运行的课程
    if (isRunning && activeId != null && activeId != name) {
      ToastUtils.show(
        '请先结束当前课程：\n$activeId',
        width: 350.w,
        height: 240.h,
      );
      return;
    }

    // 如果当前已经是打开状态，且是同一个课程，直接返回
    if (showCourseDetail && singleCourseController.courseId == name) {
      return;
    }

    if (!isRunning && singleCourseController.controlSelectedIndex != 0) {
      singleCourseController.controlSelectedIndex = 0;
      singleCourseController.update(['type_switch']);
    }

    if (singleCourseController.courseId != name) {
      singleCourseController.courseId = name;
      singleCourseController.update(['course_detail']);
    }
    singleCourseController.wallVolume = handler.wallVolume.value.clamp(0, 100);
    singleCourseController.deskVolume = handler.deskVolume.value.clamp(0, 100);
    singleCourseController.update(['volume_slider']);

    showCourseDetail = true;
    if (currentIndex != 0) {
      currentIndex = 0;
      update(['content', 'navigation']);
    }
    
    // 1. 先更新 UI 显示 Overlay (此时 Controller 已常驻，UI 可以安全构建)
    update(['main_overlay']);

    // 2. 延迟执行业务初始化，确保动画流畅
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        // 直接调用常驻的 Controller
        singleCourseController.openCourse(name).catchError((e) {
          // 仅用于排查“打开课程失败”场景，避免在 Release 下频繁 print 影响性能
          DebugUtils.log('打开课程失败: $e', name: 'course');
        });
      } catch (e) {
        // 仅用于排查同步异常，避免在 Release 下频繁 print 影响性能
        DebugUtils.log('打开课程同步异常: $e', name: 'course');
      }
    });
  }

  /// 关闭全屏课程详情覆盖层
  void closeCourseController() {
    showCourseDetail = false;
    
    // 1. 仅更新 UI 隐藏 Overlay，不销毁业务逻辑
    update(['main_overlay']);
    
    // 不再执行任何销毁逻辑，保持 Controller 状态以便悬浮窗和下次进入使用
  }

  void onTap() {}

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  @override
  /// 页面 ready 后触发初始化
  void onReady() {
    super.onReady();
    _initData();
    // 启动后异步进行“完全热启动”预热，避免阻塞当前帧
    unawaited(_warmStart());
  }

  @override
  /// 页面销毁时释放资源
  void onClose() {
    super.onClose();
  }
}
