import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import '../index.dart';

class DeviceConfigView extends GetView<IntegrationController> {
  const DeviceConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }

  Widget _buildView() {
    return <Widget>[
      _buildTopView(),
      _buildDeviceConfigItem(),
    ].toColumn();
  }

  Widget _buildTopView() {
    return <Widget>[
      ButtonWidget.icon(   
       ImageWidget.svg(
                  AssetsSvgs.settingsArrowSvg,
                  width: 20.w,
                  height: 36.h,
                  color: CustomAppColors.primary,
                ),
        onTap: () => Get.back(),
      ),
      TextWidget.label(
        '设备配置',       
      ),
    ].toRow().expanded();
  }

  Widget _buildDeviceConfigItem() {
    return <Widget>[].toColumn();
  }
}
