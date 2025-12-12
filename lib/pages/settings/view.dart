import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'index.dart';


class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  // 主视图
  Widget _buildView() {
    // 使用内部 PageView 管理“设置列表”和“关于我们”两页，实现右→左/左→右的滑动过渡
    return PageView(
      // 禁止手势滑动，点击事件中通过 animateToPage 触发动画
      physics: const NeverScrollableScrollPhysics(),
      // 控制器持有的 PageController
      controller: controller.innerPageController,
      onPageChanged: controller.onInnerPageChanged,
      // 第 0 页：设置列表；第 1 页：关于我们正文
      children: [
        // 设置列表页（仅内容区域白底，顶对齐，按内容高度）
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 38.h),
            child: <Widget>[
                LongbuttonWidget(
                  width: 1760.w,
                  height: 150.h,
                  icon: ImageWidget.svg(
                    AssetsSvgs.settingsCacheSvg,
                    width: 50.w,
                    height: 57.1.h,
                  ),
                  name: TextWidget.label(
                    '清理缓存',
                    size: 26.w,
                  ),
                  title: TextWidget.label(
                    controller.cacheCountLabel,
                    size: 26.w,
                  ),
                  subIcon: const Icon(Icons.chevron_right),
                  onTap: () => Get.dialog(
                    const ClearCacheDialog(),
                    barrierColor: Colors.black.withValues(alpha: 0.5),
                    barrierDismissible: true,
                  ),
                ),
                SizedBox(
                  width: 1680.w,
                  height: 1.h,
                ).decorated(color: CustomAppColors.border).paddingHorizontal(40.w),
                LongbuttonWidget(
                  width: 1760.w,
                  height: 150.h,
                  icon: ImageWidget.svg(
                    AssetsSvgs.settingsInfoSvg,
                    width: 50.w,
                    height: 57.1.h,
                  ),
                  name: TextWidget.label(
                    '关于我们',
                    size: 26.w,
                  ),
                  title: TextWidget.label(
                    '',
                    size: 26.w,
                  ),
                  subIcon: const Icon(Icons.chevron_right),
                  onTap: () => controller.openAbout(),
                ),
              ]
                  .toColumn(mainAxisSize: MainAxisSize.min)
                  .constrained(width: 1760.w)
                  .decorated(color: Colors.white),
          ),
        ),
        // 关于我们页
        const AboutDialogWidget()
            .constrained(width: 1760.w)
            .paddingTop(0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingsController>(
      init: SettingsController(),
      id: "settings",
      builder: (_) {
        return Scaffold(
          appBar:  _buildAppBar(context),
          body: _buildView(),
        );
      },
    );
  }

  PreferredSize _buildAppBar(BuildContext contex) {
    return PreferredSize(
      preferredSize: Size.fromHeight(160.h),
      child: AppBar(
        backgroundColor: CustomAppColors.card,
        elevation: 1,
        foregroundColor: CustomAppColors.text,
        leading: controller.isAbout
            ? IconButton(
                icon: Transform.rotate(
                  angle: math.pi,
                  child: ImageWidget.svg(
                    AssetsSvgs.settingsArrowSvg,
                    width: 20.w,
                    height: 36.h,
                  ),
                ),
                onPressed: controller.closeAbout,
              )
            : null,
        title: Text(
          controller.isAbout ? "关于我们" : "设置",
          style: TextStyle(color: CustomAppColors.text, fontSize: 40.sp),
        ),
        centerTitle: true,
        toolbarHeight: 160.h,
        automaticallyImplyLeading: false,
      ),
    );
  } 
}
