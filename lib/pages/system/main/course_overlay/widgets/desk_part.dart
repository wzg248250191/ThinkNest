import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:think_nest/common/index.dart';

import '../controller/desk_controller.dart';

class DeskPart extends GetView<DeskController> {
  const DeskPart({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DeskController>(
      id: 'desk_part',
      builder: (_) => _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    return <Widget>[
      ToggleWidget(
        firstIcon: ImageWidget.img(AssetsImages.startPlayPng),
        secondIcon: ImageWidget.img(AssetsImages.stopPlayPng),
        width: 230.w,
        height: 230.h,
        value: controller.isTesting,
        onChanged: controller.onPlayTap,
      ),
      TextWidget.label(
        controller.isTesting ? '结束试玩' : '开始试玩',
        fontSize: 36.sp,
      ).paddingTop(12.h),
    ].toColumn(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    ).alignment(Alignment.center);
  }
}
