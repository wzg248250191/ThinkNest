import 'package:ducafe_ui_core/ducafe_ui_core.dart';
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
                    fontSize: 26.sp,
                  ),
                  title: TextWidget.label(
                    controller.cacheCountLabel,
                    fontSize: 26.sp,
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
                  icon: Icon(
                    Icons.receipt_long,
                    size: 54.sp,
                    color: CustomAppColors.text,
                  ),
                  name: TextWidget.label(
                    '日志',
                    fontSize: 26.sp,
                  ),
                  title: TextWidget.label(
                    '查看近 3 天打印/错误日志',
                    fontSize: 26.sp,
                  ),
                  subIcon: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed(RouteNames.logs),
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
                    fontSize: 26.sp,
                  ),
                  title: TextWidget.label(
                    controller.appVersionLabel,
                    fontSize: 26.sp,
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
      id: "settings",
      builder: (_) {
        return Scaffold(
        appBar: AppbarWidget(
            title: controller.isAbout ? '关于我们' : '设置',
            isBack: controller.isAbout,
            onTap: controller.closeAbout,
          ),
          body: _buildView(),
        );
      },
    );
  }
}
