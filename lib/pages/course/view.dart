import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../index.dart';



class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  // 主视图
  Widget _buildView() {
    return <Widget>[
        _buildLeftList().width(1480.w),
         _buildRightNav().width(240.w),
         ] .toRow()
          .constrained(height: 808.h).center();   
  }

  Widget _buildLeftList() {
    return ScrollablePositionedList.builder(
      itemScrollController: controller.itemScrollController,
      itemPositionsListener: controller.itemPositionsListener,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 50.h),
      itemCount: controller.types.length,
      // 减少缓存的 item 数量，避免一次性渲染太多内容
      minCacheExtent: 0,
      // 添加物理效果，提升滚动手感
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final t = controller.types[index];
        // 使用 AutomaticKeepAliveClientMixin 包裹可以保持状态
        // 但这里我们使用 RepaintBoundary 来隔离重绘
        return RepaintBoundary(
          child: CourseTypeSection(
            key: ValueKey('section_$t'),
            typeName: t,
            names: controller.typeCourseNames[t],
            onCourseTap: (name) => Get.snackbar('提示', '点击了 $name'),
          ).paddingBottom(24.h),
        );
      },
    );
  }

  Widget _buildRightNav() {
    return const CourseNavWidget();
  }

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
}
