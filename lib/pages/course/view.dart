import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'index.dart';

class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  // 主视图
  Widget _buildView() {
    return const Center(
      child: Text("CoursePage"),
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
