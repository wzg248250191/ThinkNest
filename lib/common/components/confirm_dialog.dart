import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

enum ConfirmDialogLayout {
  bottomFixed,
  titleFixed,
}

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
  /// 直接弹出 ConfirmDialog（封装 Get.dialog，避免业务处重复写 barrier 参数）。
  static Future<T?> show<T>({
    required String title,
    String? leftText,
    String? rightText,
    FutureOr<void> Function()? onLeftTap,
    FutureOr<void> Function()? onRightTap,
    double? titleFontSize,
    double? titleHeight,
    double? buttonFontSize,
    double? width,
    double? buttonHeight,
    ConfirmDialogLayout layout = ConfirmDialogLayout.bottomFixed,
    bool returnBoolResult = false,
    bool barrierDismissible = false,
    Color? barrierColor,
  }) async {
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }

    return Get.dialog<T>(
      ConfirmDialog(
        title: title,
        leftText: leftText,
        rightText: rightText,
        onLeftTap: onLeftTap,
        onRightTap: onRightTap,
        titleFontSize: titleFontSize,
        titleHeight: titleHeight,
        buttonFontSize: buttonFontSize,
        width: width,
        buttonHeight: buttonHeight,
        layout: layout,
        returnBoolResult: returnBoolResult,
      ),
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.3),
    );
  }

  ConfirmDialog({
    super.key,
    required this.title,
    String? leftText,
    String? rightText,
    this.onLeftTap,
    this.onRightTap,
    double? titleFontSize,
    double? titleHeight,
    double? buttonFontSize,
    double? width,
    double? buttonHeight,
    this.layout = ConfirmDialogLayout.bottomFixed,
    this.returnBoolResult = false,
  })  : titleFontSize = titleFontSize ?? 30.sp,
        titleHeight = titleHeight ?? 100.h,
        buttonFontSize = buttonFontSize ?? 32.sp,
        width = width ?? 300.w,
        buttonHeight = buttonHeight ?? 90.h,
        leftText = leftText ?? '取消',
        rightText = rightText ?? '确认';

  /// 弹窗正文文案
  final String title;

  /// 左侧按钮文案（通常为“取消”）
  final String leftText;

  /// 右侧按钮文案（通常为“确认”）
  final String rightText;

  /// 左侧按钮松开时触发（已自动关闭弹窗）
  final FutureOr<void> Function()? onLeftTap;

  /// 右侧按钮松开时触发（已自动关闭弹窗）
  final FutureOr<void> Function()? onRightTap;

  /// 正文字号
  final double titleFontSize;

  /// 标题区域高度（用于计算弹窗真实高度=标题高度+按钮高度）
  final double titleHeight;

  /// 按钮字号
  final double buttonFontSize;

  /// 弹窗宽度
  final double width;

  /// 底部按钮条高度
  final double buttonHeight;

  final ConfirmDialogLayout layout;

  final bool returnBoolResult;

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
    required Color textColor,
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
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //Dialog 组件内部自带 ConstrainedBox(minWidth: 280.0),把 width 设到不小于 Dialog 的最小宽度，例如 width: 300.w
    final double messagePadding = 40.w;
    final double dividerThickness = 1.h;
    final Color dividerColor = CustomAppColors.text.withValues(alpha: 0.55);

    // 按压态底色：使用 onSurface 叠加，提高在不同主题下的可见性。
    final Color pressedColor = context.colors.scheme.onSurface.withValues(alpha: 0.14);

    // 底部按钮按压态由 StatefulBuilder 托管（避免把整个弹窗改为 StatefulWidget）。
    bool leftPressed = false;
    bool rightPressed = false;

    final bool isVertical = layout == ConfirmDialogLayout.titleFixed;
    // 关键逻辑：弹窗高度按“标题高度 + 按钮高度 + 分隔线 + Padding”等总和自适应。
    // 同时限制最大高度，避免总高度超过屏幕可用高度（标题区可滚动）。
    final double resolvedButtonHeight = buttonHeight;
    final double buttonsHeight =
        isVertical ? (buttonHeight * 2 + dividerThickness) : buttonHeight;
    final double maxDialogHeight = MediaQuery.sizeOf(context).height * 0.8;
    final EdgeInsets titlePadding = EdgeInsets.fromLTRB(
      messagePadding,
      messagePadding,
      messagePadding,
      messagePadding,
    );
    final double maxTitleContentHeight = (maxDialogHeight -
            dividerThickness -
            buttonsHeight -
            titlePadding.vertical)
        .clamp(0, double.infinity)
        .toDouble();
    final double resolvedTitleContentHeight =
        titleHeight.clamp(0, maxTitleContentHeight).toDouble();
    final double titleAreaHeight =
        (resolvedTitleContentHeight + titlePadding.vertical)
            .clamp(0, maxDialogHeight - dividerThickness - buttonsHeight)
            .toDouble();

    VoidCallback buildLeftTrigger() {
      return () {
        if (returnBoolResult) {
          Get.back<bool>(result: false);
        } else {
          Get.back<void>();
        }
        final cb = onLeftTap;
        if (cb != null) {
          unawaited(Future<void>.microtask(() async => cb()));
        }
      };
    }

    VoidCallback buildRightTrigger() {
      return () {
        if (returnBoolResult) {
          Get.back<bool>(result: true);
        } else {
          Get.back<void>();
        }
        final cb = onRightTap;
        if (cb != null) {
          unawaited(Future<void>.microtask(() async => cb()));
        }
      };
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: CustomAppColors.card,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            child: <Widget>[
              SizedBox(
                height: titleAreaHeight,
                child: Padding(
                  padding: titlePadding,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: TextWidget.label(
                              title,
                              fontSize: titleFontSize,
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
                height: buttonsHeight,
                child: IntrinsicHeight(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      if (isVertical) {
                        // 关键逻辑：纵向布局下，每个按钮的高度固定为 buttonHeight，不再按剩余高度平分
                        return <Widget>[
                          SizedBox(
                            height: resolvedButtonHeight,
                            child: _buildActionButton(
                              pressed: rightPressed,
                              onPressedChanged: (v) =>
                                  setState(() => rightPressed = v),
                              pressedColor: pressedColor,
                              text: rightText,
                              textFontSize: buttonFontSize,
                              textColor: CustomAppColors.primary,
                              onTrigger: buildRightTrigger(),
                            ),
                          ),
                          SizedBox(height: dividerThickness)
                              .decorated(color: dividerColor),
                          SizedBox(
                            height: resolvedButtonHeight,
                            child: _buildActionButton(
                              pressed: leftPressed,
                              onPressedChanged: (v) =>
                                  setState(() => leftPressed = v),
                              pressedColor: pressedColor,
                              text: leftText,
                              textFontSize: buttonFontSize,
                              textColor: CustomAppColors.buttonLight,
                              onTrigger: buildLeftTrigger(),
                            ),
                          ),
                        ].toColumn(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                        );
                      }

                      return <Widget>[
                        Expanded(
                          child: _buildActionButton(
                            pressed: leftPressed,
                            onPressedChanged: (v) =>
                                setState(() => leftPressed = v),
                            pressedColor: pressedColor,
                            text: leftText,
                            textFontSize: buttonFontSize,
                            textColor: CustomAppColors.buttonLight,
                            onTrigger: buildLeftTrigger(),
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
                            onPressedChanged: (v) =>
                                setState(() => rightPressed = v),
                            pressedColor: pressedColor,
                            text: rightText,
                            textFontSize: buttonFontSize,
                            textColor: CustomAppColors.buttonLight,
                            onTrigger: buildRightTrigger(),
                          ),
                        ),
                      ].toRow(crossAxisAlignment: CrossAxisAlignment.stretch);
                    },
                  ),
                ),
              ),
            ].toColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            ),
          ),
        ),
      ),
    );
  }
}

