import 'dart:math' as math;

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../index.dart';
/// 自定义AppBar组件
class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key, required this.title, this.isBack = false, this.onTap});

  final String title;
  final bool isBack;
  final Function()? onTap;

  @override
  Size get preferredSize => Size.fromHeight(160.h);

  @override
  Widget build(BuildContext context) {
    return _buildAppBar(context);
  }

  /// 构建状态栏样式，使状态栏背景与AppBar背景保持一致
  SystemUiOverlayStyle _buildSystemUiOverlayStyle() {
    final Color backgroundColor = Colors.transparent;
    return SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: backgroundColor,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
  }

  AppBar _buildAppBar(BuildContext contex) {
    return AppBar(
      backgroundColor: CustomAppColors.card,
      elevation: 1,
      foregroundColor: CustomAppColors.text,
      systemOverlayStyle: _buildSystemUiOverlayStyle(),
      leading: isBack
          ? ButtonWidget.icon(
              Transform.rotate(
                angle: math.pi,
                child: ImageWidget.svg(
                  AssetsSvgs.settingsArrowSvg,
                  width: 20.w,
                  height: 36.h,
                  color: CustomAppColors.primary,
                ),
              ),
              width: 80.w,
              height: 80.h,
              borderRadius: 999,
              enableRipple: false,
              onTap: onTap,
            )
          : null,
      title: TextWidget(
        text: title,
        color: CustomAppColors.text,
        fontSize: 40.sp,
      ),
      centerTitle: true,
      toolbarHeight: 160.h,
      automaticallyImplyLeading: false,
    );
  }
}
