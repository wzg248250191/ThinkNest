import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:think_nest/common/index.dart';

import '../controller/wall_controller.dart';

class Wallpart extends GetView<WallController> {
  const Wallpart({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildView(context);
  }

  Widget _buildView(BuildContext context) {
    return <Widget>[
      _buildCard('学生互动区', WallArea.left),
      _buildCard('老师讲解区区', WallArea.middle),
      _buildCard('学生互动区', WallArea.right),
    ]
        .toRow(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.center)
        .alignment(Alignment.center);
  }

  Widget _buildCard(String title, WallArea area) {
    RxBool powerObs;
    RxBool interactObs;
    switch (area) {
      case WallArea.left:
        powerObs = controller.leftPower;
        interactObs = controller.leftInteract;
        break;
      case WallArea.middle:
        powerObs = controller.midPower;
        interactObs = controller.midInteract;
        break;
      case WallArea.right:
        powerObs = controller.rightPower;
        interactObs = controller.rightInteract;
        break;
    }

    return <Widget>[
      TextWidget.label(
        title,
        fontSize: 36.sp,
      ),
      Obx(() => ToggleButton(
        firstText: '关闭墙面',
        secondText: '开启墙面',
        width: 160.w,
        height: 76.h,
        fontSize: 28.sp,
        value: powerObs.value,
        textColorOff: CustomAppColors.subText,
        textColorOn: CustomAppColors.subText,
        backgroundColorOff: CustomAppColors.card,
        backgroundColorOn: CustomAppColors.card,
        variantOff: ButtonWidgetVariant.outline,
        variantOn: ButtonWidgetVariant.outline,
        borderColor: CustomAppColors.text,
        onChanged: (v) => controller.onWallPowerChanged(area, v),
      )),
      Obx(() => ToggleButton(
        firstText: '关闭互动',
        secondText: '开启互动',
        width: 160.w,
        height: 76.h,
        fontSize: 28.sp,
        value: interactObs.value,
        textColorOff: CustomAppColors.subText,
        textColorOn: CustomAppColors.subText,
        backgroundColorOff: CustomAppColors.card,
        backgroundColorOn: CustomAppColors.card,
        variantOff: ButtonWidgetVariant.outline,
        variantOn: ButtonWidgetVariant.outline,
        borderColor: CustomAppColors.text,
        onChanged: (v) => controller.onWallInteractChanged(area, v),
      )),
      ButtonWidget.outline(
        '重新开始',
        width: 160.w,
        height: 76.h,
        fontSize: 28.sp,
        textColor: CustomAppColors.subText,
        backgroundColor: CustomAppColors.card,
        borderColor: CustomAppColors.text,
        onTap: () => controller.onWallRestartTap(area),
      ),
    ]
        .toColumn(mainAxisAlignment: MainAxisAlignment.spaceAround)
        .width(410.w)
        .height(610.h)
        .decorated(
          color: CustomAppColors.border,
          borderRadius: BorderRadius.circular(12.r),
        );
  }
}
