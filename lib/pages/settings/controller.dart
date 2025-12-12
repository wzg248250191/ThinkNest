import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class SettingsController extends GetxController {
  SettingsController();

  String cacheCountLabel = '';
  bool isAbout = false;
  // 内部 PageView 的控制器，用于右侧内容滑动切换
  final PageController innerPageController = PageController(initialPage: 0);

  _initData() {
    update(["settings"]);
  }

  void onTap() {}

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  @override
  void onReady() {
    super.onReady();
    _initData();
    loadCacheCount();
  }

  // @override
  // void onClose() {
  //   super.onClose();
  // }

///读取缓存数量
  Future<void> loadCacheCount() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}libCachedImageData');
      var count = 0;

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            count++;
          }
        }
      }

      cacheCountLabel = '缓存($count)';
    } catch (_) {
      cacheCountLabel = '缓存(0)';
    }

    update(["settings"]);
  }

///清除缓存
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}libCachedImageData');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
    await loadCacheCount();
  }

  void openAbout() {
    // 右→左滑入“关于我们”页
    innerPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isAbout = true;
    update(["settings"]);
  }

  void closeAbout() {
    // 左→右滑出返回设置列表
    innerPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isAbout = false;
    update(["settings"]);
  }

  void onInnerPageChanged(int index) {
    // 同步 isAbout 状态，供 AppBar 返回键与标题联动
    isAbout = index == 1;
    update(["settings"]);
  }

  @override
  void onClose() {
    // 释放内部 PageController
    innerPageController.dispose();
    super.onClose();
  }
}
