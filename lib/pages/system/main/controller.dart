import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainController extends GetxController {
  MainController();

  // 分页管理
  final PageController pageController = PageController();

  // 当前的 tab index
  int currentIndex = 0;

  // 退出请求时间
  DateTime? currentBackPressTime;

  /// 课程控制：互斥按钮当前选中索引（0/1）
  int courseControlSelectedIndex = 0;

  /// 设置课程控制互斥按钮选中项并刷新 UI
  void setCourseControlSelectedIndex(int index) {
    courseControlSelectedIndex = index;
    update(['course_control_toggle']);
  }


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

///课程控制
  String? currentCourseName;
  bool showCourseDetail = false;
  //打开课程控制
  /// 打开全屏课程详情覆盖层，并保证停留在课程 tab
  void openCourseController(String name) {
    currentCourseName = name;
    showCourseDetail = true;
    courseControlSelectedIndex = 0;
    if (currentIndex != 0) {
      currentIndex = 0;
      update(['content', 'navigation']);
    }
    update(['course_control_toggle']);
    update(['main_overlay']);
  }

  /// 关闭全屏课程详情覆盖层
  void closeCourseController() {
    showCourseDetail = false;
    currentCourseName = null;
    update(['main_overlay']);
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
