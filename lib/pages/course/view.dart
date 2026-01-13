import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

import '../../common/index.dart';
import '../index.dart';


class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  @override
  /// 构建课程页面（课程列表 + 右侧分类导航）
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GetBuilder<CourseController>(
            id: "course_list",
            builder: (_) {
              return _buildView();
            },
          ),
          const FloatingCourseWidget(),
        ],
      ),
    );
  }

  Widget _buildSyncBannerSlot() {
    return GetBuilder<CourseController>(
      id: "course_sync_banner",
      builder: (_) {
        final hasAnyCourse = controller.typeCourseNames.values.any((e) => e.isNotEmpty);
        final bool showSyncBanner = controller.isCourseListLoading && hasAnyCourse;
        final double height = 90.h;

        if (!showSyncBanner) {
          return SizedBox(height: height);
        }
        return SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: 1720.w,
              child: <Widget>[
                SizedBox(
                  width: 1480.w,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: CustomAppColors.card.withAlpha(235),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: <Widget>[
                        PulseDot(
                          size: 25.w,
                          color: CustomAppColors.primary,
                          enabled: true,
                        ),
                        SizedBox(width: 12.w),
                        TextWidget.label(
                          '正在同步课程清单…',
                          fontSize: 22.sp,
                          color: CustomAppColors.subText,
                        ),
                      ].toRow(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 240.w),
              ].toRow(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildView() {
    final row = <Widget>[
      SizedBox(width: 1480.w, child: _buildCourseList()),
      SizedBox(width: 240.w, child: const CourseNavWidget()),
    ].toRow().constrained(height: 808.h);

    final banner = _buildSyncBannerSlot();
    final double bannerOffsetY = -(808.h / 2 + 90.h / 2);

    return Stack(
      alignment: Alignment.center,
      children: [
        row.center(),
        Transform.translate(
          offset: Offset(0, bannerOffsetY),
          child: banner,
        ),
      ],
    );
  }

  /// 使用 CustomScrollView + SliverGrid 构建课程列表
  /// 说明：
  /// - 当本地有缓存课程清单时：优先展示列表，顶部显示“同步中”提示，等待服务端数据刷新
  /// - 当无缓存且仍在加载时：显示全屏加载态
  Widget _buildCourseList() {
    final hasAnyCourse = controller.typeCourseNames.values.any((e) => e.isNotEmpty);
    if (controller.isCourseListLoading && !hasAnyCourse) {
      return _buildCourseListLoading();
    }
    // 按你的要求：只保留“全量构建”方案
    return _buildEagerCourseList();
  }

  /// 全量构建模式：用 SingleChildScrollView + Column 一次性构建全部课程内容
  /// 说明：
  /// - 不使用 SliverGrid 懒构建，避免滚动过程中边滑边创建子项导致卡顿
  /// - 代价：首次进入会更慢、内存占用更高（由 Splash 白屏/启动图遮挡）
  Widget _buildEagerCourseList() {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < controller.types.length; i++) {
      final String typeName = controller.types[i];
      final List<String> courses = controller.typeCourseNames[typeName] ?? const <String>[];

      children.add(_buildSectionTitle(typeName, controller.sectionKeys[i]));
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: CourseController.listPaddingHorizontal),
          child: _buildEagerCourseGrid(typeName, courses),
        ),
      );
      children.add(SizedBox(height: 24.h));
    }

    // 底部安全间距
    children.add(SizedBox(height: 50.h));

    return SingleChildScrollView(
      controller: controller.scrollController,
      physics: const ClampingScrollPhysics(),
      child: children.toColumn(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    );
  }

  /// 全量构建模式：把课程按 5 列拆成多行 Row，一次性构建全部 CourseWidget
  Widget _buildEagerCourseGrid(String typeName, List<String> courses) {
    if (courses.isEmpty) {
      return const SizedBox.shrink();
    }

    final double listWidth = 1480.w;
    final double contentWidth =
        (listWidth - 2 * CourseController.listPaddingHorizontal).clamp(1.0, double.infinity);
    final double totalSpacing =
        (CourseController.crossAxisCount - 1) * CourseController.crossAxisSpacing;
    final double cellWidth =
        ((contentWidth - totalSpacing) / CourseController.crossAxisCount).clamp(1.0, double.infinity);
    final double cellHeight = (cellWidth / (238 / 320)).clamp(1.0, double.infinity);

    final int perRow = CourseController.crossAxisCount;
    final int rowCount = (courses.length / perRow).ceil().clamp(0, 999999);

    final List<Widget> rows = <Widget>[];
    for (int r = 0; r < rowCount; r++) {
      final List<Widget> rowChildren = <Widget>[];
      for (int c = 0; c < perRow; c++) {
        final int index = r * perRow + c;
        if (index < courses.length) {
          final String courseName = courses[index];
          rowChildren.add(
            SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: RepaintBoundary(
                child: CourseWidget(
                  key: ValueKey('${typeName}_$courseName'),
                  name: courseName,
                  onTap: () {
                    if (Get.isRegistered<MainController>()) {
                      Get.find<MainController>().openCourseController(courseName);
                      return;
                    }
                    Get.snackbar('提示', '点击了 $courseName');
                  },
                ),
              ),
            ),
          );
        } else {
          // 补齐空位，保证每行宽度一致（对齐原网格）
          rowChildren.add(SizedBox(width: cellWidth, height: cellHeight));
        }

        if (c != perRow - 1) {
          rowChildren.add(SizedBox(width: CourseController.crossAxisSpacing));
        }
      }

      rows.add(
        rowChildren.toRow(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      );

      if (r != rowCount - 1) {
        rows.add(SizedBox(height: CourseController.mainAxisSpacing));
      }
    }

    return rows.toColumn(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }

  /// 构建“等待服务器下发课程清单”的加载态内容
  Widget _buildCourseListLoading() {
    return <Widget>[
      PulseDot(
        size: 18.w,
        color: CustomAppColors.primary,
      ),
      SizedBox(height: 18.h),
      TextWidget.label(
        '正在获取课程清单…',
        fontSize: 28.sp,
        color: CustomAppColors.subText,
      ),
    ].toColumn(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  /// 构建分类标题
  Widget _buildSectionTitle(String typeName, GlobalKey sectionKey) {
    final en = courseType[typeName] ?? '';    
    return Container(
      key: sectionKey,
      padding: EdgeInsets.only(
        left: CourseController.listPaddingHorizontal,
        right: CourseController.listPaddingHorizontal,
        bottom: 24.h,
      ),
      child: <Widget>[
        TextWidget.rich(
          TextSpan(
            children: [
              TextSpan(
                text: typeName,
                style: const TextStyle(color: CustomAppColors.primary),
              ),
              TextSpan(
                text: ' /$en',
                style: TextStyle(
                  color: CustomAppColors.subText,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          fontSize: 36.sp,
          weight: FontWeight.w600,
        ),
       // SizedBox(height: 6.h),
        ImageWidget.img(
          AssetsImages.courseSplitPng,
          width: 1350.w,
          height: 39.h,
         // fit: BoxFit.contain,
         // alignment: Alignment.centerLeft,
        ),
      ].toColumn(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    );
  }
}
