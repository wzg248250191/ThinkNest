import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

class DeviceConfigView extends GetView<IntegrationController> {
  const DeviceConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }

  Widget _buildView() {
    const titles = [
      '墙面主机',
      '墙面投影',
      '桌面主机',
      '桌面投影',
      '灯光',
      '窗帘',
    ];

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      itemCount: titles.length,
      separatorBuilder: (_, __) => SizedBox(height: 24.h),
      itemBuilder: (_, index) => DeviceInfoItem(title: titles[index]),
    );
  }
}
