import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

class AlertDialog {
  static Future<bool> show(
    String title, {
    String btnName1 = '确定',
    String btnName2 = '取消',
  }) async {
    // 如果已有 Toast 显示，先关闭（防止堆叠）
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    final double minWidth = 250.w;
    final double maxWidth = 600.w;
    final double horizontalPadding = 40.w * 2;
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(fontSize: 28.sp),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 10000);
    final double dialogWidth =
        (titlePainter.width + horizontalPadding).clamp(minWidth, maxWidth);

    final bool? result = await Get.dialog<bool>(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: CustomAppColors.card,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: <Widget>[
              TextWidget.label(
                title,
                fontSize: 28.sp,
                textAlign: TextAlign.center,
                softWrap: true,
              ).paddingOnly(
                left: 40.w,
                right: 40.w,
                top: 30.h,
                bottom: 20.h,
              ),
              SizedBox(width: double.infinity, height: 0.3.h)
                  .decorated(color: Colors.black),
              ButtonWidget.ghost(
                btnName1,
                 width: double.infinity,
                fontSize: 24.sp,
                textColor: CustomAppColors.primary,
                onTap: () => Get.back(result: true),
              ),
              SizedBox(width: double.infinity, height: 0.3.h)
                  .decorated(color: Colors.black),
              ButtonWidget.ghost(
                btnName2,
                width: double.infinity,
                  fontSize: 24.sp,
                onTap: () => Get.back(result: false),
              ),
              //SizedBox(height: 30.h),
            ].toColumn(mainAxisSize: MainAxisSize.min),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
    );
    return result ?? false;
  }
}
