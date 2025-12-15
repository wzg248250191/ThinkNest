import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

import 'index.dart';
import 'widgets/course.dart' as cw;

class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  // 主视图
  Widget _buildView() {
    final items = <Widget>[
      cw.CourseWidget(name: '不上你的当', onTap: () => Get.snackbar('提示', '点击了 跳动的小音符')),
      cw.CourseWidget(name: '小小指纹真神奇', onTap: () => Get.snackbar('提示', '点击了 节奏与律动')),
      cw.CourseWidget(name: '我防溺水有高招', onTap: () => Get.snackbar('提示', '点击了 神奇的乐器')),
    ];
    return Center(
      child: Wrap(
        spacing: 24.w,
        runSpacing: 24.h,
        children: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CourseController>(
      init: CourseController(),
      id: "course",
      builder: (_) {
        return Scaffold(
          //appBar: AppBar(title: const Text("course")),
          body: _buildView(),
        );
      },
    );
  }
}
