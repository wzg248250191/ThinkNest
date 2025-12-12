// ignore_for_file: unused_local_variable

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../index.dart';

/// 导航栏数据模型
class NavigationItemModel {
  final String label;
  final String icon;
  final int count;
  final double? iconWidth; // 图标宽度
  final double? iconHeight; // 图标高度
  final double? fontSize; // 文字大小
  final FontWeight? fontWeight; // 文字粗细
  final double? itemHeight; // 按钮高度（单个项可配置）

  NavigationItemModel({
    required this.label,
    required this.icon,
    this.count = 0,
    this.iconWidth,
    this.iconHeight,
    this.fontSize,
    this.fontWeight,
    this.itemHeight,
  });
}

/// 导航栏
class BuildNavigation extends StatelessWidget {
  final int currentIndex;
  final List<NavigationItemModel> items;
  final Function(int) onTap;

  // 默认样式配置
  final double defaultIconWidth;
  final double defaultIconHeight;
  final double defaultFontSize;
  final FontWeight defaultFontWeight;
  final double? defaultItemHeight; // 全局默认按钮高度（为空则均分高度）
  final double selectedScale; // 选中项缩放倍率
  final Duration selectedScaleDuration; // 缩放动画时长
  final Curve selectedScaleCurve; // 缩放动画曲线

  const BuildNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.defaultIconWidth = 24, // 默认图标宽
    this.defaultIconHeight = 24, // 默认图标高
    this.defaultFontSize = 14, // 默认字号
    this.defaultFontWeight = FontWeight.w400, // 默认字重
    this.defaultItemHeight, // 默认 null：保持当前 Expanded 均分
    this.selectedScale = 1.08,
    this.selectedScaleDuration = const Duration(milliseconds: 200),
    this.selectedScaleCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    var ws = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      var color = (i == currentIndex)
          ? context.colors.scheme.primary
          : context.colors.scheme.onSurfaceVariant;
      var bgColor = context.colors.scheme.secondaryContainer.withValues(
        alpha: 0.18,
      );
      var item = items[i];
      var isSelected = i == currentIndex;
      var scale = isSelected ? selectedScale : 1.0;
      var content = <Widget>[
        IconWidget.svg(
          item.icon,
          width: item.iconWidth?.w ?? defaultIconWidth.w,
          height: item.iconHeight?.h ?? defaultIconHeight.h,
          color: color,
          badgeString: item.count > 0 ? item.count.toString() : null,
        ).paddingBottom(20.h),
        TextWidget.label(
          item.label.tr,
          size: item.fontSize?.sp ?? defaultFontSize.sp,
          weight: item.fontWeight ?? defaultFontWeight,
          color: color,
        ),
      ]
          .toColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
          ).center()
         // .decorated(color: bgColor)
          .onTap(() => onTap(i));

      var scaled = AnimatedScale(
        scale: scale,
        duration: selectedScaleDuration,
        curve: selectedScaleCurve,
        child: content,
      );

      final usedHeight = item.itemHeight ?? defaultItemHeight;
      if (usedHeight != null) {
        ws.add(SizedBox(height: usedHeight.h, child: scaled));
      } else {
        ws.add(scaled.expanded());
      }
    }
    // 改为左侧垂直导航 (NavigationRail 风格)
    return Container(
      color: context.colors.scheme.surface,
      width: 240.w, // 移除固定宽度，由外部决定
      // height: double.infinity, // 移除无限高度，防止在 Column 中报错
      child: ws
          .toColumn(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 改为居中
            crossAxisAlignment: CrossAxisAlignment.center,
          )
          .paddingVertical(20.h), // 顶部底部留白
    );
  }
}
