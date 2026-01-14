import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';
import '../../../common/index.dart';

///设备配置视图
///
///说明：
///- 用于显示和编辑设备的基本配置（如 IP 地址、端口号、打开/关闭指令等）
class DeviceConfigView extends GetView<IntegrationController> {
  const DeviceConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }

  /// 构建设备配置页顶部“导入/导出”操作区
  Widget _buildImportExportActions() {
    final exportPath = FutureBuilder<String>(
      future: controller.deviceConfigsExportsDirPath(),
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        final text = path.isEmpty ? '导出目录：加载中...' : '导出目录：$path';
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: path.isEmpty ? null : controller.openDeviceConfigsExportsDir,
          onLongPress: path.isEmpty ? null : controller.copyDeviceConfigsExportsDirPath,
          child: TextWidget.label(
            text,
            fontSize: 22.sp,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    ).expanded();

    return <Widget>[
      exportPath,
      SizedBox(width: 16.w),
      ButtonWidget.outline(
        '打开',
        width: 140.w,
        height: 56.h,
        fontSize: 26.sp,
        onTap: controller.openDeviceConfigsExportsDir,
      ),
      SizedBox(width: 16.w),
      ButtonWidget.outline(
        '导入',
        width: 160.w,
        height: 56.h,
        fontSize: 26.sp,
        onTap: controller.importDeviceConfigsCsv,
      ),
      SizedBox(width: 16.w),
      ButtonWidget.outline(
        '导出',
        width: 160.w,
        height: 56.h,
        fontSize: 26.sp,
        onTap: controller.exportDeviceConfigsCsv,
      ),
    ].toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween);
  }

  Widget _buildView() {
    return GetBuilder<IntegrationController>(
      id: kDeviceConfigGetBuilderId,
      builder: (_) {
        final titles = IntegrationController.deviceTitles;
        return <Widget>[
          _buildImportExportActions().paddingOnly(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: 10.h,
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
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
            ),
          ),
        ].toColumn(crossAxisAlignment: CrossAxisAlignment.stretch);
      },
    );
  }
}
