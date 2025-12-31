import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'device_config_view.dart';
import 'index.dart';

class IntegrationPage extends GetView<IntegrationController> {
  const IntegrationPage({super.key});

  // 主视图
  Widget _buildView() {
    return  <Widget>[
      SwitchCircleButton(
        name: '总开关',
        iconBuilder: (color) => ImageWidget.svg(
          AssetsSvgs.iconLightningSvg,
          width: 63.69.w,
          height: 92.53.h,
          color: color,
        ),
        size: 200.w,
        state: controller.switchState(IntegrationSwitchType.main),
        onStateChanged: (value) => controller.onSwitchStateChanged(IntegrationSwitchType.main, value),
      ).paddingBottom(100.w),
      <Widget>[
     SwitchCircleButton(
        name: '墙面开关',
        iconBuilder: (color) => ImageWidget.svg(
          AssetsSvgs.iconWallSvg,
          width: 118.55.w,
          height: 42.w,
          color: color,
        ),
        size: 200.w,
        state: controller.switchState(IntegrationSwitchType.wall),
        onStateChanged: (value) => controller.onSwitchStateChanged(IntegrationSwitchType.wall, value),
      ),
      SwitchCircleButton(
        name: '桌面开关',
        iconBuilder: (color) => ImageWidget.svg(
          AssetsSvgs.iconDeskSvg,
          width: 107.98.w,
          height: 68.w,
          color: color,
        ),
        size: 200.w,
        state: controller.switchState(IntegrationSwitchType.desk),
        onStateChanged: (value) => controller.onSwitchStateChanged(IntegrationSwitchType.desk, value),
      ),
      SwitchCircleButton(
        name: '灯光开关',
        iconBuilder: (color) => ImageWidget.svg(
          AssetsSvgs.iconLightSvg,
          width: 69.72.w,
          height: 102.22.w,
          color: color,
        ),
        size: 200.w,
        state: controller.switchState(IntegrationSwitchType.light),
        onStateChanged: (value) => controller.onSwitchStateChanged(IntegrationSwitchType.light, value),
      ),
      SwitchCircleButton(
        name: '窗帘开关',
        iconBuilder: (color) => ImageWidget.svg(
          AssetsSvgs.iconCurtainSvg,
          width: 89.27.w,
          height: 84.w,
          color: color,
        ),
        size: 200.w,
        state: controller.switchState(IntegrationSwitchType.curtain),
        onStateChanged: (value) => controller.onSwitchStateChanged(IntegrationSwitchType.curtain, value),
      )].toRow(mainAxisAlignment: MainAxisAlignment.spaceEvenly)
    ].toColumn(mainAxisAlignment: MainAxisAlignment.center).center();
  }

  Widget _buildEntryPage() {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildView(),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.onDeviceConfigEntryTap,
            child: Container(
              width: 120.w,
              height: 120.w,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return PageView(
      physics: const NeverScrollableScrollPhysics(),
      controller: controller.innerPageController,
      onPageChanged: controller.onInnerPageChanged,
      children: [
        _buildEntryPage(),
        const DeviceConfigView(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IntegrationController>(
      id: "integration",
      builder: (_) {
        return  Scaffold(
            appBar: AppbarWidget(
              title: controller.isConfig ? '设备配置' : '一体化设置',
              isBack: controller.isConfig,
              onTap: controller.closeConfig,
              ),
            body: _buildBody(),
          );
      },
    );
  }
}
