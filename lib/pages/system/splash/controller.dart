import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/index.dart';
import '../../course/controller.dart';

class SplashController extends GetxController {
  SplashController();

  /// 初始化并刷新启动页状态
  void _initData() {
    update(["splash"]);
  }

  void onTap() {}

  /// 启动期间预加载：课程清单 + 图片缓存 + 课程页全量构建模式开关
  Future<void> _preloadAndEnter() async {
    // 预加载依赖：提前注册 CourseController，后续进入课程页不再重复初始化
    final CourseController courseController = Get.isRegistered<CourseController>()
        ? Get.find<CourseController>()
        : Get.put<CourseController>(CourseController(), permanent: true);

    // 启用“全量构建模式”：课程页会一次性构建全部课程卡片，滚动/跳转不再触发懒构建
    courseController.enableFullBuildAllMode();

    // 预加载课程数据与图片资源（不依赖 BuildContext，避免 async gap 风险）
    await courseController.preloadForSplash();

    // 预加载完成后进入主页面
    Get.offAllNamed(RouteNames.systemMain);
  }

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  @override
  void onReady() {
    super.onReady();
    _initData();
    // 等首帧渲染完成后再做启动期预加载，避免阻塞当前帧
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAndEnter();
    });
  }

  // @override
  // void onClose() {
  //   super.onClose();
  // }
}
