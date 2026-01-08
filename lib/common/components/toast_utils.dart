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
/// 使用 Overlay 实现，无需 Context，支持自定义样式
/// 背景为全屏半透明,
class ToastUtils {
  static bool _isShowing = false;
  static Timer? _dismissTimer;
  static int _hideLockedUntilMs = 0;
  static int _generation = 0;
  static OverlayEntry? _overlayEntry;
  static final ValueNotifier<_ToastPayload?> _payload =
      ValueNotifier<_ToastPayload?>(null);
  static final double _minWidth = 210.w;
  static final double _maxWidth = 600.w;
  static final double _minHeight = 210.h;
  static final double _maxHeight = 600.h;
  static final double _defaultFontSize = 28.sp;

  static OverlayState? _getOverlayState() {
    final overlayFromKey = Get.key.currentState?.overlay;
    if (overlayFromKey != null) {
      return overlayFromKey;
    }

    final BuildContext? overlayContext = Get.overlayContext;
    if (overlayContext != null) {
      return Overlay.of(overlayContext, rootOverlay: true);
    }

    final BuildContext? context = Get.context;
    if (context != null) {
      return Overlay.of(context, rootOverlay: true);
    }

    return null;
  }

  static void _ensureOverlayEntry() {
    if (_overlayEntry != null) {
      return;
    }

    final overlayState = _getOverlayState();
    if (overlayState == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<_ToastPayload?>(
          valueListenable: _payload,
          builder: (context, value, _) {
            if (value == null) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: [
                ModalBarrier(
                  dismissible: false,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: value.width,
                      height: value.height,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40.w,
                        vertical: 30.h,
                      ),
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
                      child: value.isLoading
                          ? <Widget>[
                              SizedBox(
                                width: 64.sp,
                                height: 64.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4.sp,
                                  backgroundColor:
                                      CustomAppColors.text.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    CustomAppColors.text,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              Text(
                                value.msg,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: CustomAppColors.text,
                                  fontSize:
                                      value.fontSize ?? _defaultFontSize,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ].toColumn(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                            )
                          : <Widget>[
                              value.customIcon ??
                                  _buildIcon(
                                    value.type,
                                    iconStyle: value.iconStyle,
                                  ),
                              SizedBox(height: 20.h),
                              Text(
                                value.msg,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: CustomAppColors.text,
                                  fontSize:
                                      value.fontSize ?? _defaultFontSize,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ].toColumn(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    overlayState.insert(_overlayEntry!);
    _isShowing = true;
  }

  static void _preemptFlow() {
    _generation++;
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  /// 隐藏当前 Toast/Loading 弹层
  static void hide({bool force = false}) {
    if (_isShowing) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now < _hideLockedUntilMs) {
        return;
      }
    }

    _preemptFlow();

    _payload.value = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;

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
    hide(force: true);
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
    _preemptFlow();

    lockHide(duration);
    _ensureOverlayEntry();
    if (_overlayEntry == null) {
      return;
    }
    _payload.value = _ToastPayload.toast(
      msg: msg,
      type: type,
      iconStyle: iconStyle,
      customIcon: customIcon,
      width: width,
      height: height,
      fontSize: fontSize,
    );

    // 定时关闭
    final int token = _generation;
    _dismissTimer = Timer(duration, () {
      if (token != _generation) {
        return;
      }
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
    _preemptFlow();
    _hideLockedUntilMs = 0;

    _ensureOverlayEntry();
    if (_overlayEntry == null) {
      return;
    }
    _payload.value = _ToastPayload.loading(
      msg: msg,
      width: width,
      height: height,
      fontSize: fontSize,
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

class _ToastPayload {
  const _ToastPayload({
    required this.msg,
    required this.isLoading,
    required this.type,
    required this.iconStyle,
    required this.customIcon,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  factory _ToastPayload.toast({
    required String msg,
    required ToastType type,
    required ToastIconStyle iconStyle,
    required Widget? customIcon,
    required double? width,
    required double? height,
    required double? fontSize,
  }) {
    return _ToastPayload(
      msg: msg,
      isLoading: false,
      type: type,
      iconStyle: iconStyle,
      customIcon: customIcon,
      width: width,
      height: height,
      fontSize: fontSize,
    );
  }

  factory _ToastPayload.loading({
    required String msg,
    required double? width,
    required double? height,
    required double? fontSize,
  }) {
    return _ToastPayload(
      msg: msg,
      isLoading: true,
      type: ToastType.info,
      iconStyle: ToastIconStyle.thick,
      customIcon: null,
      width: width,
      height: height,
      fontSize: fontSize,
    );
  }

  final String msg;
  final bool isLoading;
  final ToastType type;
  final ToastIconStyle iconStyle;
  final Widget? customIcon;
  final double? width;
  final double? height;
  final double? fontSize;
}
