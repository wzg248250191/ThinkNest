import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'models/switch_circle_state.dart';

class IntegrationController extends GetxController {
  IntegrationController();

  //总开关
  SwitchCircleState mainState = const SwitchCircleState(enabled: true, isOn: true);
  //墙面开关
  SwitchCircleState wallState = const SwitchCircleState(enabled: true, isOn: false);
  //桌面开关
  SwitchCircleState deskState = const SwitchCircleState(enabled: true, isOn: false);
  //灯光开关
  SwitchCircleState lightState = const SwitchCircleState(enabled: false, isOn: false);
  //窗帘开关
  SwitchCircleState curtainState = const SwitchCircleState(enabled: false, isOn: false);

  // 内部 PageView 的控制器，用于右侧内容滑动切换
  final PageController innerPageController = PageController(initialPage: 0);
  bool isConfig = false;
  int _deviceConfigTapCount = 0;
  DateTime? _lastDeviceConfigTapAt;

  void setMainState(SwitchCircleState value) {
    mainState = value;
    update(["integration"]);
  }

  void setWallState(SwitchCircleState value) {
    wallState = value;
    update(["integration"]);
  }

void setDeskState(SwitchCircleState value) {
    deskState = value;
    update(["integration"]);
  }

  void setLightState(SwitchCircleState value) {
    lightState = value;
    update(["integration"]);
  }

  
  void setCurtainState(SwitchCircleState value) {
    curtainState = value;
    update(["integration"]);
  }

  void onDeviceConfigEntryTap() {
    if (isConfig) {
      return;
    }

    final now = DateTime.now();
    final last = _lastDeviceConfigTapAt;
    if (last == null || now.difference(last) > const Duration(milliseconds: 1200)) {
      _deviceConfigTapCount = 0;
    }

    _lastDeviceConfigTapAt = now;
    _deviceConfigTapCount += 1;

    if (_deviceConfigTapCount >= 5) {
      openConfig();
    }
  }

  void openConfig() {
    // 右→左滑入“关于我们”页
    innerPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = true;
    update(["integration"]);
  }

  void closeConfig() {
    // 左→右滑出返回设置列表
    innerPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = false;
    update(["integration"]);
  }

  void onInnerPageChanged(int index) {
    isConfig = index == 1;
    update(["integration"]);
  }

  _initData() {
    update(["integration"]);
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
  }

  @override
  void onClose() {
    innerPageController.dispose();
    super.onClose();
  }
}
