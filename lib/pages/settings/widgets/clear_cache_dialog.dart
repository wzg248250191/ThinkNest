import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';
import '../controller.dart';

class ClearCacheDialog extends StatelessWidget {
  const ClearCacheDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 380.w,
        height: 230.h,
        // padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
        decoration: BoxDecoration(
          color: CustomAppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: <Widget>[
          TextWidget.label(
            '确定清空本地缓存数据？',
            size: 26.w,
            textAlign: TextAlign.center,
          ).paddingTop(30.w).paddingBottom(50.h),
          Container(height: 3.h).decorated(color: CustomAppColors.border),
          Expanded(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: ButtonWidget.raw(
                        variant: ButtonWidgetVariant.ghost,
                        scale: WidgetScale.medium,
                        onTap: () => Get.back(),                      
                        child: TextWidget.label('取消', size: 32.w),
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 3.w,
                    thickness: 3.w,
                    color: CustomAppColors.border,
                  ),
                  Expanded(
                    child: Center(
                      child: ButtonWidget.raw(
                        variant: ButtonWidgetVariant.ghost,
                        scale: WidgetScale.medium,
                        onTap: () async {
                          await Get.find<SettingsController>().clearCache();
                          Get.back();
                          _showSuccessToast();
                        },                    
                        child: TextWidget.label('确定', size: 32.w),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ].toColumn(),
      ),
    );
  }

//显示清除成功提示
  void _showSuccessToast() {
    Get.dialog(
      Center(
        child: Container(
          width: 200.w,
          height: 200.w,
          decoration: BoxDecoration(
            color: CustomAppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, color: Colors.green, size: 72.w),
              SizedBox(height: 20.h),
              TextWidget.label('清除成功', size: 32.w),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    });
  }
}
