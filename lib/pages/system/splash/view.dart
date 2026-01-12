import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
    return _NativeSplashHandoff(
      child: GetBuilder<SplashController>(
        init: SplashController(),
        id: "splash",
        builder: (_) {
          return _buildView();
        },
      ),
    );
  }

}

class _NativeSplashHandoff extends StatefulWidget {
  const _NativeSplashHandoff({required this.child});

  final Widget child;

  @override
  /// 创建状态对象，用于在首帧后移除 Native Splash
  State<_NativeSplashHandoff> createState() => _NativeSplashHandoffState();
}

class _NativeSplashHandoffState extends State<_NativeSplashHandoff> {
  bool _started = false;

  @override
  /// 依赖变化时触发一次“首帧后移除 Native Splash”，减少原生启动图停留时间
  void didChangeDependencies() {
    super.didChangeDependencies();
    _removeNativeSplashAfterFirstFrame();
  }

  /// 在首帧完成后移除 Native Splash，让自定义 SplashPage 接管显示
  Future<void> _removeNativeSplashAfterFirstFrame() async {
    if (_started) {
      return;
    }
    _started = true;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    FlutterNativeSplash.remove();
  }

  @override
  /// 构建桥接容器：只负责移除 Native Splash，不改变子组件布局
  Widget build(BuildContext context) {
    return widget.child;
  }
}
