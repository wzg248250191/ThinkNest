import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../common/index.dart';
import '../../index.dart';

class MainPage extends GetView<MainController> {
  const MainPage({super.key});

   // 主视图
  Widget _buildView(BuildContext context) {
    return PopScope(
      // 允许返回
      canPop: false,

      // 防止连续点击两次退出
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // 如果返回，则不执行退出请求
        if (didPop) {
          return;
        }

        // 退出请求
        if (controller.closeOnConfirm(context)) {
          SystemNavigator.pop(); // 系统级别导航栈 退出程序
        }
      },

      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        // 内容页
        body: Row(
          children: [
            Container(
              width: 240.w,
              color: Colors.white,
              child: Column(
                children: [
                  ImageWidget.img(
                    AssetsImages.logoPng,
                    width: 107.84.w,
                    height: 120.99.h,
                  ).paddingTop(60.h),
                  Expanded(
                    child: GetBuilder<MainController>(
                      id: 'navigation',
                      builder: (controller) {
                        return BuildNavigation(
                          currentIndex: controller.currentIndex,
                          selectedScale: 1.3,
                          items: [
                            NavigationItemModel(
                              label: "开始上课",
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              icon: AssetsSvgs.navStartSvg,
                              iconWidth: 52.2,
                              iconHeight: 50.27,  
                              itemHeight: 250.w                         
                            ),
                            NavigationItemModel(
                              label: "一体化",
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              icon: AssetsSvgs.navIntegratedSvg,
                              iconWidth: 52.44,
                              iconHeight: 52.41,
                              itemHeight: 250.w
                            ),
                            NavigationItemModel(
                              label: "设置",
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              icon: AssetsSvgs.navSettingsSvg,
                              iconWidth: 50.28,
                              iconHeight: 47.52,
                              itemHeight:250.w
                            )
                          ],
                          onTap: controller.onJumpToPage,
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
                // 左侧导航容器阴影：提升立体感，避免与内容区贴合
                .elevation(
                  8,
                  borderRadius: BorderRadius.zero,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                )
                // 右侧分隔边框：与右侧内容区域做视觉分隔
                .decorated(
                  border: Border(
                    right: BorderSide(
                      color: context.colors.scheme.outline,
                      width: AppBorder.card,
                    ),
                  ),
                ),
            // 右侧渐变阴影条：增强阴影可见性（深->浅）
            Container(
              width: 3.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: controller.pageController,
                onPageChanged: controller.onIndexChanged,
                children: [
                  CoursePage(),
                  IntegrationPage(),
                  SettingsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return GetBuilder<MainController>(
      init: MainController(),
      id: "main",
      builder: (_) {
        return Scaffold(
          body: _buildView(context),
        );
      },
    );
  }
}
