import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'index.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  // 主视图
  Widget _buildView() {
    return const Center(
      child: Text("SettingsPage"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingsController>(
      init: SettingsController(),
      id: "settings",
      builder: (_) {
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(160.h),
              child: AppBar(
                backgroundColor: CustomAppColors.background,
                elevation: 1,
                title: Text(
                  "设置",
                  style: TextStyle(
                    color: CustomAppColors.text,
                    fontSize: 40.sp,
                  ),
                ),
                centerTitle: true,
                toolbarHeight: 160.h,
                automaticallyImplyLeading: false,
              ),
            ),
            body: _buildView(),
          ),
        );
      },
    );
  }
}
