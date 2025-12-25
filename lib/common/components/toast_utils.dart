// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:think_nest/common/style/theme.dart'; // 引入项目中常用的 UI 库以适配屏幕适配

/// Toast 类型枚举
enum ToastType {
  info, // 感叹号 (默认)
  error, // 错误 X
  success, // 成功 √
  warning, // 警告 !
}

/// 全局通用的 Toast 提示工具类
/// 使用 Get.dialog 实现，无需 Context，支持自定义样式
class ToastUtils {
  
  /// 显示 Toast
  /// [msg] 提示文本
  /// [type] 提示类型，默认为 info (感叹号)
  /// [customIcon] 自定义图标 Widget (如果传入，则忽略 type)
  /// [duration] 显示时长，默认 2 秒
  /// [width] 容器宽度，不传则自适应
  /// [height] 容器高度，不传则自适应
  /// [fontSize] 字体大小，默认 28.sp
  static void show(
    String msg, {
    ToastType type = ToastType.info,
    Widget? customIcon,
    Duration duration = const Duration(seconds: 2),
    double? width,
    double? height,
    double? fontSize,
  }) {
    // 如果已有 Toast 显示，先关闭（防止堆叠）
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
            decoration: BoxDecoration(
              color: CustomAppColors.background, // 黑色半透明背景 (0xB3 = 70% opacity)
              borderRadius: BorderRadius.circular(16.r),
            ),
            // 最小宽度限制，避免文字太少时太窄
            constraints: BoxConstraints(
              minWidth: 240.w,
              maxWidth: 600.w,
              minHeight: 180.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标区域
                customIcon ?? _buildIcon(type),
                SizedBox(height: 20.h),
                // 文字区域
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CustomAppColors.text,
                    fontSize: fontSize ?? 28.sp,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.3), // 全屏淡色遮罩背景
      barrierDismissible: false, // 禁止点击背景关闭，拦截所有点击事件
    );

    // 定时关闭
    Timer(duration, () {
      // 只有当前还在显示 Dialog 时才关闭
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }

  static Widget _buildIcon(ToastType type) {
    IconData iconData;
    Color color = CustomAppColors.text;

    switch (type) {
      case ToastType.info:
        iconData = Icons.error_outline_rounded; // 圆圈感叹号
        break;
      case ToastType.error:
        iconData = Icons.highlight_off_rounded; // 圆圈 X
        break;
      case ToastType.success:
        iconData = Icons.check_circle_outline_rounded; // 圆圈 √
        break;
      case ToastType.warning:
        iconData = Icons.warning_amber_rounded; // 三角警告
        break;
    }

    return Icon(
      iconData,
      color: color,
      size: 64.sp,
    );
  }
}
