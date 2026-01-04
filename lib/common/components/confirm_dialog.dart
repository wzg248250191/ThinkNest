import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.message,
    required this.leftText,
    required this.rightText,
    this.onLeftTap,
    this.onRightTap,
    this.messageFontSize,
    this.buttonFontSize,
    this.width,
    this.height,
    this.buttonHeight,
  });

  final String message;
  final String leftText;
  final String rightText;
  final FutureOr<void> Function()? onLeftTap;
  final FutureOr<void> Function()? onRightTap;
  final double? messageFontSize;
  final double? buttonFontSize;
  final double? width;
  final double? height;
  final double? buttonHeight;

  @override
  Widget build(BuildContext context) {
    //Dialog 组件内部自带 ConstrainedBox(minWidth: 280.0),把 width 设到不小于 Dialog 的最小宽度，例如 width: 300.w
    final double resolvedWidth = width ?? 300.w;
    final double resolvedHeight = height ?? 230.h;
    final double resolvedButtonHeight = buttonHeight ?? 90.h;
    final double resolvedMessageFontSize = messageFontSize ?? 26.sp;
    final double resolvedButtonFontSize = buttonFontSize ?? 26.sp;
    final double messagePaddingH = 40.w;
    final double messagePaddingTop = 30.h;
    final double messagePaddingBottom = 30.h;
    final double dividerThickness = 1.h;
    final Color dividerColor = CustomAppColors.text.withValues(alpha: 0.55);

    final double contentHeight = (resolvedHeight - dividerThickness - resolvedButtonHeight)
        .clamp(0, double.infinity)
        .toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: resolvedWidth,
        height: resolvedHeight,
        decoration: BoxDecoration(
          color: CustomAppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
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
                          fontSize: resolvedMessageFontSize,
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
            height: resolvedButtonHeight,
            child: IntrinsicHeight(
              child: <Widget>[
                Expanded(
                  child: SizedBox.expand(
                    child: ButtonWidget.raw(
                      variant: ButtonWidgetVariant.ghost,
                      scale: WidgetScale.medium,
                      onTap: () {
                        Get.back<void>();
                        final cb = onLeftTap;
                        if (cb != null) {
                          unawaited(Future<void>.microtask(() async => cb()));
                        }
                      },
                      child: SizedBox.expand(
                        child: Center(
                          child: TextWidget.label(
                            leftText,
                            fontSize: resolvedButtonFontSize,
                            color: CustomAppColors.buttonLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1.w,
                  thickness: 1.w,
                  color: dividerColor,
                ),
                Expanded(
                  child: SizedBox.expand(
                    child: ButtonWidget.raw(
                      variant: ButtonWidgetVariant.ghost,
                      scale: WidgetScale.medium,
                      onTap: () {
                        Get.back<void>();
                        final cb = onRightTap;
                        if (cb != null) {
                          unawaited(Future<void>.microtask(() async => cb()));
                        }
                      },
                      child: SizedBox.expand(
                        child: Center(
                          child: TextWidget.label(
                            rightText,
                            fontSize: resolvedButtonFontSize,
                            color: CustomAppColors.buttonLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ].toRow(crossAxisAlignment: CrossAxisAlignment.stretch),
            ),
          ),
        ].toColumn(crossAxisAlignment: CrossAxisAlignment.stretch),
      ),
    );
  }
}

