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

  NavigationItemModel({
    required this.label,
    required this.icon,
    this.count = 0,
    this.iconWidth,
    this.iconHeight,
    this.fontSize,
    this.fontWeight,
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

  const BuildNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.defaultIconWidth = 24, // 默认图标宽
    this.defaultIconHeight = 24, // 默认图标高
    this.defaultFontSize = 14, // 默认字号
    this.defaultFontWeight = FontWeight.w400, // 默认字重
  });

  @override
  Widget build(BuildContext context) {
    var ws = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      var color = (i == currentIndex)
          ? context.colors.scheme.primary
          : context.colors.scheme.onSurfaceVariant;
      var item = items[i];
      ws.add(
        <Widget>[
          // 图标
          IconWidget.svg(
            item.icon,
            width: item.iconWidth?.w ?? defaultIconWidth.w, // 优先使用 item 配置，否则用默认
            height: item.iconHeight?.h ?? defaultIconHeight.h,
            color: color,
            badgeString: item.count > 0 ? item.count.toString() : null,
          ).paddingBottom(20.h), // 图片和文字之间的间距

          // 文字
          TextWidget.label(
            item.label.tr,
            size: item.fontSize?.sp ?? defaultFontSize.sp, // 优先使用 item 配置，否则用默认
            weight: item.fontWeight ?? defaultFontWeight,
            color: color,
          ),
        ]
            .toColumn(
              mainAxisAlignment: MainAxisAlignment.center, // 居中
              mainAxisSize: MainAxisSize.max, // 最大
            )
            .onTap(() => onTap(i))
            .expanded(),
      );
    }
    
    // 如果是底部导航
    /*return BottomAppBar(
      color: context.colors.scheme.surface,
      elevation: 0,
      child: ws
          .toRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
          )
          .height(kBottomNavigationBarHeight),
    );*/

    // 改为左侧垂直导航 (NavigationRail 风格)
    return Container(
      color: context.colors.scheme.surface,
      width: 240.w, // 移除固定宽度，由外部决定
      // height: double.infinity, // 移除无限高度，防止在 Column 中报错
      child: ws
          .toColumn(
            mainAxisAlignment: MainAxisAlignment.center, // 改为居中
            crossAxisAlignment: CrossAxisAlignment.center,
          )
          .paddingVertical(20.h), // 顶部底部留白
    );
  }
}
