import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

/// 通用二次确认弹窗（正文 + 底部左右两个操作按钮）。
///
/// 交互约定：
/// - 底部按钮“按下时变色、松开时触发”（更贴近原生确认弹窗手感）
/// - 不使用涟漪动画，仅用按压态底色反馈
///
/// 尺寸/字体默认值说明：
/// - 这里使用 `sp/w/h` 这类适配单位，它们不是编译期常量，无法写成命名参数默认值
/// - 因此默认值放在构造函数初始化列表里：未传参 -> 使用默认；传参 -> 覆盖默认
class ConfirmDialog extends StatelessWidget {
  ConfirmDialog({
    super.key,
    required this.message,
    required this.leftText,
    required this.rightText,
    this.onLeftTap,
    this.onRightTap,
    double? messageFontSize,
    double? buttonFontSize,
    double? width,
    double? height,
    double? buttonHeight,
  })  : messageFontSize = messageFontSize ?? 26.sp,
        buttonFontSize = buttonFontSize ?? 32.sp,
        width = width ?? 300.w,
        height = height ?? 230.h,
        buttonHeight = buttonHeight ?? 90.h;

  /// 弹窗正文文案
  final String message;

  /// 左侧按钮文案（通常为“取消”）
  final String leftText;

  /// 右侧按钮文案（通常为“确认”）
  final String rightText;

  /// 左侧按钮松开时触发（已自动关闭弹窗）
  final FutureOr<void> Function()? onLeftTap;

  /// 右侧按钮松开时触发（已自动关闭弹窗）
  final FutureOr<void> Function()? onRightTap;

  /// 正文字号
  final double messageFontSize;

  /// 按钮字号
  final double buttonFontSize;

  /// 弹窗宽度
  final double width;

  /// 弹窗高度
  final double height;

  /// 底部按钮条高度
  final double buttonHeight;

  /// 构建底部单个操作按钮（按住变色、松开触发）。
  ///
  /// 这里用 `Listener` 而不是 `onTap`：
  /// - `onTap` 会受“长按/轻微移动”等手势竞争影响，导致按住松开不触发
  /// - `onPointerUp` 可保证“松开”必触发（除非被系统取消）
  Widget _buildActionButton({
    required bool pressed,
    required ValueChanged<bool> onPressedChanged,
    required Color pressedColor,
    required String text,
    required double textFontSize,
    required VoidCallback onTrigger,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPressedChanged(true),
      onPointerUp: (_) {
        onPressedChanged(false);
        onTrigger();
      },
      onPointerCancel: (_) => onPressedChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: pressed ? pressedColor : Colors.transparent,
        child: Center(
          child: TextWidget.label(
            text,
            fontSize: textFontSize,
            color: CustomAppColors.buttonLight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //Dialog 组件内部自带 ConstrainedBox(minWidth: 280.0),把 width 设到不小于 Dialog 的最小宽度，例如 width: 300.w
    final double messagePaddingH = 40.w;
    final double messagePaddingTop = 30.h;
    final double messagePaddingBottom = 30.h;
    final double dividerThickness = 1.h;
    final Color dividerColor = CustomAppColors.text.withValues(alpha: 0.55);

    // 按压态底色：使用 onSurface 叠加，提高在不同主题下的可见性。
    final Color pressedColor = context.colors.scheme.onSurface.withValues(alpha: 0.14);

    // 底部按钮按压态由 StatefulBuilder 托管（避免把整个弹窗改为 StatefulWidget）。
    bool leftPressed = false;
    bool rightPressed = false;

    // 正文区域高度 = 总高度 - 分割线 - 底部按钮条高度
    final double contentHeight = (height - dividerThickness - buttonHeight)
        .clamp(0, double.infinity)
        .toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: CustomAppColors.card,
          ),
          child: <Widget>[
            SizedBox(
              height: contentHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  messagePaddingH,
                  messagePaddingTop,
                  messagePaddingH,
                  messagePaddingBottom,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: TextWidget.label(
                            message,
                            fontSize: messageFontSize,
                            textAlign: TextAlign.center,
                            weight: FontWeight.w500,
                            softWrap: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: dividerThickness).decorated(color: dividerColor),
            SizedBox(
              height: buttonHeight,
              child: IntrinsicHeight(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return <Widget>[
                      Expanded(
                        child: _buildActionButton(
                          pressed: leftPressed,
                          onPressedChanged: (v) => setState(() => leftPressed = v),
                          pressedColor: pressedColor,
                          text: leftText,
                          textFontSize: buttonFontSize,
                          onTrigger: () {
                            Get.back<void>();
                            final cb = onLeftTap;
                            if (cb != null) {
                              unawaited(Future<void>.microtask(() async => cb()));
                            }
                          },
                        ),
                      ),
                      VerticalDivider(
                        width: 1.w,
                        thickness: 1.w,
                        color: dividerColor,
                      ),
                      Expanded(
                        child: _buildActionButton(
                          pressed: rightPressed,
                          onPressedChanged: (v) => setState(() => rightPressed = v),
                          pressedColor: pressedColor,
                          text: rightText,
                          textFontSize: buttonFontSize,
                          onTrigger: () {
                            Get.back<void>();
                            final cb = onRightTap;
                            if (cb != null) {
                              unawaited(Future<void>.microtask(() async => cb()));
                            }
                          },
                        ),
                      ),
                    ].toRow(crossAxisAlignment: CrossAxisAlignment.stretch);
                  },
                ),
              ),
            ),
          ].toColumn(crossAxisAlignment: CrossAxisAlignment.stretch),
        ),
      ),
    );
  }
}

