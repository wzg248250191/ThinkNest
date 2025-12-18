import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

import 'controller.dart';
import 'widgets/course_type.dart';
import 'widgets/course.dart';
import 'widgets/course_nav_widget.dart';
import '../../common/index.dart';

class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CourseController>(
      id: "course",
      builder: (_) {
        return Scaffold(
          body: _buildView(),
        );
      },
    );
  }

  Widget _buildView() {
    return Row(
      children: [
        // 左侧课程列表
        SizedBox(
          width: 1480.w,
          child: _buildCourseList(),
        ),
        // 右侧导航栏
        SizedBox(
          width: 240.w,
          child: const CourseNavWidget(),
        ),
      ],
    ).constrained(height: 808.h).center();
  }

  /// 使用 CustomScrollView + SliverGrid 构建课程列表
  Widget _buildCourseList() {
    return CustomScrollView(
      controller: controller.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: _buildSlivers(),
    );
  }

  /// 构建所有 Sliver 组件
  List<Widget> _buildSlivers() {
    final List<Widget> slivers = [];
    
    // 顶部间距
    slivers.add(SliverToBoxAdapter(
      child: SizedBox(height: CourseController.listPaddingTop),
    ));
    
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
      child: SizedBox(
        height: 64.h,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: typeName,
                  style: const TextStyle(color: CustomAppColors.primary),
                ),
                const TextSpan(text: '/'),
                TextSpan(
                  text: en,
                  style: const TextStyle(color: CustomAppColors.subText),
                ),
              ],
            ),
            style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600),
          ),
        ),
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
              onTap: () => Get.snackbar('提示', '点击了 $courseName'),
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
