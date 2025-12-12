import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

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
        state: controller.mainState,
        onStateChanged: controller.setMainState,
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
        state: controller.wallState,
        onStateChanged: controller.setWallState,
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
        state: controller.deskState,
        onStateChanged: controller.setDeskState,
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
        state: controller.lightState,
        onStateChanged: controller.setLightState,
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
        state: controller.curtainState,
        onStateChanged: controller.setCurtainState,
      )].toRow(mainAxisAlignment: MainAxisAlignment.spaceEvenly)
    ].toColumn(mainAxisAlignment: MainAxisAlignment.center).center();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IntegrationController>(
      init: IntegrationController(),
      id: "integration",
      builder: (_) {
        return  Scaffold(
            appBar: _buildAppBar(context),
            body: _buildView(),
          );
      },
    );
  }

  PreferredSize _buildAppBar(BuildContext contex) {
    return PreferredSize(
      preferredSize: Size.fromHeight(160.h),
      child: AppBar(
        backgroundColor: CustomAppColors.card,
        elevation: 1,
        title: Text(
          "一体化设置",
          style: TextStyle(color: CustomAppColors.text, fontSize: 40.sp),
        ),
        centerTitle: true,
        toolbarHeight: 160.h,
        automaticallyImplyLeading: false,
      ),
    );
  }
}
