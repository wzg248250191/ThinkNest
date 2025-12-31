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
    return GetBuilder<CourseController>(
      id: "course",
      builder: (_) {
        return Scaffold(
          body: Stack(
            children: [
              _buildView(),
              const FloatingCourseWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncBannerSlot() {
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
                      size: 14.w,
                      color: CustomAppColors.primary,
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
    return CustomScrollView(
      controller: controller.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: _buildSlivers(),
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

  /// 构建所有 Sliver 组件
  List<Widget> _buildSlivers() {
    final List<Widget> slivers = [];
    
    // 遍历每个分类
    for (int i = 0; i < controller.types.length; i++) {
      final typeName = controller.types[i];
      final courses = controller.typeCourseNames[typeName] ?? [];
      
      // 分类标题（带 GlobalKey 用于定位）
      slivers.add(SliverToBoxAdapter(
        child: _buildSectionTitle(typeName, controller.sectionKeys[i]),
      ));
      
      // 课程网格
      slivers.add(SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: CourseController.listPaddingHorizontal,
        ),
        sliver: _buildCourseGrid(typeName, courses),
      ));
      
      // 分类底部间距
      slivers.add(SliverToBoxAdapter(
        child: SizedBox(height: 24.h),
      ));
    }
    
    // 底部安全间距
    slivers.add(SliverToBoxAdapter(
      child: SizedBox(height: 50.h),
    ));
    
    return slivers;
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
        ImageWidget.svg(
          AssetsSvgs.courseSplitSvg,
          width: 1350.w,
          height: 39.h,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      ].toColumn(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    );
  }

  /// 构建课程网格 - 使用 SliverGrid 实现真正的懒加载
  Widget _buildCourseGrid(String typeName, List<String> courses) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: CourseController.crossAxisCount,
        crossAxisSpacing: CourseController.crossAxisSpacing,
        mainAxisSpacing: CourseController.mainAxisSpacing,
        childAspectRatio: 238 / 320,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final courseName = courses[index];
          return RepaintBoundary(
            child: CourseWidget(
              key: ValueKey('${typeName}_$courseName'),
              name: courseName,
              onTap: () {
                // 点击课程时，打开课程详情控制器
                if (Get.isRegistered<MainController>()) {
                  Get.find<MainController>().openCourseController(courseName);
                  return;
                }
                Get.snackbar('提示', '点击了 $courseName');
              },
            ),
          );
        },
        childCount: courses.length,
        // 🚀 性能优化：禁用自动 KeepAlive，减少内存占用
        addAutomaticKeepAlives: false,
        // 🚀 已手动添加 RepaintBoundary，禁用自动添加
        addRepaintBoundaries: false,
      ),
    );
  }
}
