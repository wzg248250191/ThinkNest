import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/index.dart';
import 'index.dart';
//什么时候出现 ： Flutter 引擎加载完毕 ，第一帧渲染出来之后。通常紧接着 Native Splash 显示;
// 作用 ： 展示应用的 logo 或 启动动画，给用户一种应用正在加载的感觉。
class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

   // 主视图
  Widget _buildView() {
    return const ImageWidget.img(
      AssetsImages.splashPng,
      fit: BoxFit.fill, // 填充整个界面
    );
  }


   @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      id: "splash",
      builder: (_) {
        return _buildView();
      },
    );
  }

}
