import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'widgets/pulse_dot.dart';

import 'index.dart';
import 'widgets/course_type.dart';
import '../../common/index.dart';

class CoursePage extends GetView<CourseController> {
  const CoursePage({super.key});

  // 主视图
  Widget _buildView() {
    return Center(
      child: <Widget>[_buildLeftList().constrained(width: 1480.w), _buildRightNav()]
          .toRow()
          .constrained(width: 1720.w, height: 808.h),
    );
  }

  Widget _buildLeftList() {
    return ScrollablePositionedList.builder(
      itemScrollController: controller.itemScrollController,
      itemPositionsListener: controller.itemPositionsListener,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 50.h),
      itemCount: controller.types.length,
      itemBuilder: (context, index) {
        final t = controller.types[index];
        return CourseTypeSection(
          typeName: t,
          onCourseTap: (name) => Get.snackbar('提示', '点击了 $name'),
        ).paddingBottom(24.h);
      },
    );
  }

  Widget _buildRightNav() {
    return GetBuilder<CourseController>(
      id: 'course_nav',
      builder: (_) {
        final items = controller.types;
        final double maxBox = 21.w;
        final double baseCenterX = maxBox / 2;
        final double selectedSize = 21.w;
        final children = List<Widget>.generate(items.length, (i) {
          final selected = i == controller.currentTypeIndex;
          final double dotSize = 14.w;
          final Widget dotCore = Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: CustomAppColors.primary, width: 2.w),
            ),
          );
          final Widget dot = SizedBox(width: maxBox, height: maxBox, child: Center(child: dotCore));
          final label = TextWidget.label(
            items[i],
            size: selected ? 36.sp : 26.sp,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? CustomAppColors.primary : CustomAppColors.subText,
          );
          final isFirst = i == 0;
          final isLast = i == items.length - 1;
          final isOnly = items.length == 1;
          final factor = isOnly ? 0.0 : ((isFirst || isLast) ? 0.5 : 1.0);
          final double lineLeft = baseCenterX;

          final navRow = <Widget>[
            Align(alignment: Alignment.centerRight, child: label).expanded(),
            SizedBox(width: 0.w),
            dot,
          ].toRow(crossAxisAlignment: CrossAxisAlignment.center).paddingVertical(16.h);

          final rowStack = Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(right: lineLeft),
                    child: Align(
                      alignment: isFirst
                          ? Alignment.bottomRight
                          : (isLast ? Alignment.topRight : Alignment.centerRight),
                      child: FractionallySizedBox(
                        heightFactor: factor,
                        child: Container(
                          width: 2.w,
                          color: CustomAppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => controller.scrollToSection(i),
                behavior: HitTestBehavior.translucent,
                child: Center(child: navRow),
              ),
            ],
          );
          return Container(key: controller.navItemKeys[i], child: rowStack).expanded();
        });

        final navColumn = RepaintBoundary(
          child: <Widget>[...children]
            .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
            .paddingSymmetric(horizontal: 24.w)
            .constrained(width: 240.w, height: 808.h)
            .decorated(color: Colors.transparent),
        );
        final overlay = GetBuilder<CourseController>(
          id: 'course_nav_overlay',
          builder: (_) {
            final double slideY =
                (controller.overlayCenterY - selectedSize / 2) / selectedSize;
            return Positioned(
              right: 24.w + baseCenterX - selectedSize / 2,
              top: 0,
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: Offset(0, slideY),
                    duration: Duration(milliseconds: controller.navAnimDurationMs),
                    curve: Curves.linearToEaseOut,
                    child: PulseDot(
                      size: selectedSize,
                      color: CustomAppColors.primary,
                      enabled: !controller.isNavAnimating,
                    ),
                  ),
                ),
              ),
            );
          },
        );
        return Container(
          key: controller.navContainerKey,
          child: Stack(
            children: [
              navColumn,
              overlay,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CourseController>(
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
