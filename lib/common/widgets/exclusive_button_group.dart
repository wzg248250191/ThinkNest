import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';

import '../index.dart';


class ExclusiveButtonGroup extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double buttonWidth;
  final double buttonHeight;
  final double groupRadius;
  final double fontSize;
  final double borderWidth;
  final Color groupBackgroundColor;
  final Color unselectedBackgroundColor;
  final Color borderColor;
  final Color dividerColor;

  /// 可切换按钮组
  const ExclusiveButtonGroup({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.groupRadius,
    required this.fontSize,
    required this.borderWidth,
    this.groupBackgroundColor = CustomAppColors.card,
    this.unselectedBackgroundColor = CustomAppColors.card,
    this.borderColor = CustomAppColors.border,
    this.dividerColor = CustomAppColors.border,
  }) : assert(labels.length >= 2, 'labels 至少需要 2 个元素');

  @override
  Widget build(BuildContext context) {
    final groupWidth =
        buttonWidth * labels.length + borderWidth * (labels.length - 1);

    Widget buildSegment(int index) {
      final bool isFirst = index == 0;
      final bool isLast = index == labels.length - 1;
      final bool selected = selectedIndex == index;
      final BorderRadius radius = BorderRadius.horizontal(
        left: isFirst ? Radius.circular(groupRadius) : Radius.zero,
        right: isLast ? Radius.circular(groupRadius) : Radius.zero,
      );

      return SizedBox(
        width: buttonWidth,
        height: buttonHeight,
        child: ClipRRect(
          borderRadius: radius,
          child: ButtonWidget(
            variant: selected
                ? ButtonWidgetVariant.primary
                : ButtonWidgetVariant.ghost,
            text: labels[index],
            fontSize: fontSize,
            backgroundColor: selected ? null : unselectedBackgroundColor,
            width: buttonWidth,
            height: buttonHeight,
            borderRadius: 0,
            onTap: () => onSelected(index),
          ),
        ),
      );
    }

    final divider = Container(
      width: borderWidth,
      height: buttonHeight,
      color: dividerColor,
    );

    final segments = <Widget>[];
    for (int i = 0; i < labels.length; i++) {
      segments.add(buildSegment(i));
      if (i != labels.length - 1) {
        segments.add(divider);
      }
    }

    return SizedBox(
      width: groupWidth,
      height: buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: groupBackgroundColor,
          borderRadius: BorderRadius.circular(groupRadius),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: segments.toRow(),
      ),
    );
  }
}
