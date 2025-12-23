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
    return GetBuilder<IntegrationController>(
      id: 'device_config',
      builder: (_) {
        final titles = IntegrationController.deviceTitles;
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          itemCount: titles.length,
          separatorBuilder: (_, __) => SizedBox(height: 24.h),
          itemBuilder: (_, index) {
            final title = titles[index];
            final cfg = controller.getDeviceConfig(title);
            return DeviceInfoItem(
              title: title,
              enabled: cfg.enabled,
              commandBase: cfg.commandBase,
              ip: cfg.ip,
              port: cfg.port,
              openCmd: cfg.openCmd,
              closeCmd: cfg.closeCmd,
              queryCmd: cfg.queryCmd,
              onChanged: (next) => controller.setDeviceConfig(title, next),
            );
          },
        );
      },
    );
  }
}
