import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'index.dart';

class IntegrationPage extends GetView<IntegrationController> {
  const IntegrationPage({super.key});

  // 主视图
  Widget _buildView() {
    return const Center(
      child: Text("IntegrationPage"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IntegrationController>(
      init: IntegrationController(),
      id: "integration",
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: const Text("integration")),
          body: SafeArea(
            child: _buildView(),
          ),
        );
      },
    );
  }
}
