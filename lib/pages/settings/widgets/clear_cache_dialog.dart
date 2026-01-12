import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import '../controller.dart';

class ClearCacheDialog extends StatelessWidget {
  const ClearCacheDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ConfirmDialog(
      title: '确定清空本地缓存数据？',
      leftText: '取消',
      rightText: '确定',
      onRightTap: () async {
        await Get.find<SettingsController>().clearCache();
        await Future.delayed(const Duration(milliseconds: 300));
        _showSuccessToast();
      },
      width: 380.w,
    );
  }

  void _showSuccessToast() {
    ToastUtils.show(
      '清除成功',
      type: ToastType.success,
      duration: const Duration(seconds: 1),
      width: 170.w,
      height: 170.h,
      fontSize: 32.sp,
    );
  }
}
