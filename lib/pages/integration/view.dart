import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'index.dart';

class IntegrationPage extends GetView<IntegrationController> {
  const IntegrationPage({super.key});

  // 主视图
  Widget _buildView() {
    return const Center(
      child: Text("IntegrationPage"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IntegrationController>(
      init: IntegrationController(),
      id: "integration",
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
                  "一体化设置",
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
