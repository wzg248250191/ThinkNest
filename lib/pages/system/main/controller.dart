import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/index.dart';
import '../../index.dart';

class MainController extends GetxController {
  MainController();

  // 分页管理
  final PageController pageController = PageController();

  // 当前的 tab index
  int currentIndex = 0;

  // 退出请求时间
  DateTime? currentBackPressTime;

  /// 初始化主页面数据并触发首次刷新
  _initData() {
    update(["main"]);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Center(child: Text('Press again to exit the application.')),
          duration: Duration(seconds: 4),
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
    // 获取 Handler 实例（数据源）
    final handler = Get.find<PcCourseMessageHandler>();
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
    if (showCourseDetail && Get.find<SingleCourseController>().courseId == name) {
      return;
    }
    
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
        Get.find<SingleCourseController>().openCourse(name).catchError((e) {
          print('Error opening course: $e');
        });
      } catch (e) {
        print('Sync Error opening course: $e');
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
  }

  @override
  /// 页面销毁时释放资源
  void onClose() {
    super.onClose();
    // 释放页控制器
    pageController.dispose();
  }
}
