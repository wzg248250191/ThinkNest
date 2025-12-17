import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../controller.dart';
import 'course_type.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

class CourseListPane extends GetView<CourseController> {
  const CourseListPane({super.key});
  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      itemScrollController: controller.itemScrollController,
      itemPositionsListener: controller.itemPositionsListener,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 50.h),
      itemCount: controller.types.length,
      // 添加缓存范围，提前渲染屏幕外的内容
      minCacheExtent: 500,
      itemBuilder: (context, index) {
        final t = controller.types[index];
        // 使用 Padding 替代扩展方法，减少 Widget 层级
        return Padding(
          padding: EdgeInsets.only(bottom: 24.h),
          child: CourseTypeSection(
            key: ValueKey('course_type_$t'),
            typeName: t,
            onCourseTap: (name) => Get.snackbar('提示', '点击了 $name'),
          ),
        );
      },
    );
  }
}
