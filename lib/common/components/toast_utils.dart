// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../index.dart';


/// Toast 类型枚举
enum ToastType {
  info, // 感叹号 (默认)
  error, // 错误 X
  success, // 成功 √
  warning, // 警告 !
}

enum ToastIconStyle {
  thick,//粗
  thin,//细
}

/// 全局通用的 Toast 提示工具类
/// 使用 Get.dialog 实现，无需 Context，支持自定义样式
/// 背景为全屏半透明,
class ToastUtils {
  static bool _isShowing = false;
  static Timer? _dismissTimer;
  static int _hideLockedUntilMs = 0;
  static final double _minWidth = 210.w;
  static final double _maxWidth = 600.w;
  static final double _minHeight = 210.h;
  static final double _maxHeight = 600.h;
  static final double _defaultFontSize = 28.sp;

  /// 隐藏当前 Toast/Loading 弹层
  static void hide({bool force = false}) {
    if (_isShowing) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now < _hideLockedUntilMs) {
        return;
      }
    }

    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_isShowing) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _isShowing = false;
    }

    if (force) {
      _hideLockedUntilMs = 0;
    }
  }

  static void lockHide(Duration duration) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int next = now + duration.inMilliseconds;
    if (next > _hideLockedUntilMs) {
      _hideLockedUntilMs = next;
    }
  }

  /// 强制重置显示状态，防止因异常导致的死锁
  static void resetState() {
    _isShowing = false;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _hideLockedUntilMs = 0;
  }

  /// 显示 Toast
  /// [msg] 提示文本
  /// [type] 提示类型，默认为 info (感叹号)
  /// [iconStyle] 图标线条风格，默认粗
  /// [customIcon] 自定义图标 Widget (如果传入，则忽略 type)
  /// [duration] 显示时长，默认 2 秒
  /// [width] 容器宽度，不传则自适应
  /// [height] 容器高度，不传则自适应
  /// [fontSize] 字体大小，默认 28.sp
  static void show(
    String msg, {
    ToastType type = ToastType.info,
    ToastIconStyle iconStyle = ToastIconStyle.thick,
    Widget? customIcon,
    Duration duration = const Duration(seconds: 2),
    double? width,
    double? height,
    double? fontSize,
  }) {
    hide(force: true);

    _isShowing = true;
    lockHide(duration);
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
              minWidth: _minWidth,
              maxWidth: _maxWidth,
              minHeight: _minHeight,
              maxHeight: _maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标区域
                customIcon ?? _buildIcon(type, iconStyle: iconStyle),
                SizedBox(height: 20.h),
                // 文字区域
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CustomAppColors.text,
                    fontSize: fontSize ?? _defaultFontSize,
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
    _dismissTimer?.cancel();
    _dismissTimer = Timer(duration, () {
      hide(force: true);
    });
  }

  /// 显示全屏 Loading（旋转圆圈），需手动调用 [hide] 关闭
  /// [msg] 提示文本
  /// [width] 容器宽度，不传则自适应
  /// [height] 容器高度，不传则自适应
  /// [fontSize] 字体大小，默认 28.sp
  static void showLoading(
    String msg, {
    double? width,
    double? height,
    double? fontSize,
  }) {
    hide(force: true);

    _isShowing = true;
    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
            decoration: BoxDecoration(
              color: CustomAppColors.background,
              borderRadius: BorderRadius.circular(16.r),
            ),
            constraints: BoxConstraints(
              minWidth: _minWidth,
              maxWidth: _maxWidth,
              minHeight: _minHeight,
              maxHeight: _maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64.sp,
                  height: 64.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 4.sp,
                    backgroundColor: CustomAppColors.text.withOpacity(0.2),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(CustomAppColors.text),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CustomAppColors.text,
                    fontSize: fontSize ?? _defaultFontSize,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.3),
      barrierDismissible: false,
    );
  }

  static Widget _buildIcon(
    ToastType type, {
    ToastIconStyle iconStyle = ToastIconStyle.thick,
  }) {
    IconData iconData;
    Color color = CustomAppColors.text;
    final bool isThin = iconStyle == ToastIconStyle.thin;

    if (isThin) {
      switch (type) {
        case ToastType.info:
          iconData = Symbols.info; // 圆圈 i
          break;
        case ToastType.error:
          iconData = Symbols.cancel; // 圆圈 X
          break;
        case ToastType.success:
          iconData = Symbols.check_circle; // 圆圈 √
          break;
        case ToastType.warning:
          iconData = Symbols.warning; // 三角警告
          break;
      }
    } else {
      switch (type) {
        case ToastType.info:
          iconData = Icons.error_outline; // 圆圈感叹号
          break;
        case ToastType.error:
          iconData = Icons.highlight_off; // 圆圈 X
          break;
        case ToastType.success:
          iconData = Icons.check_circle_outline; // 圆圈 √
          break;
        case ToastType.warning:
          iconData = Icons.warning_amber_outlined; // 三角警告
          break;
      }
    }

    return Icon(
      iconData,
      color: color,
      size: 64.sp,
      fill: isThin ? 0 : null,
      weight: isThin ? 200 : null,
      grade: isThin ? -25 : null,
      opticalSize: isThin ? 64 : null,
    );
  }
}
