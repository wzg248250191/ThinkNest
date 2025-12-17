import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../controller.dart';
import '../../../common/index.dart';
import 'pulse_dot.dart';

class CourseNavPane extends GetView<CourseController> {
  const CourseNavPane({super.key});
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<CourseController>(
      id: 'course_nav',
      builder: (_) {
        final items = controller.types;
        final double maxBox = 21.w;
        final double baseCenterX = maxBox / 2;
        final double selectedSize = 21.w;
        
        // 构建导航项列表 - 使用标准 Flutter Widget
        final children = List<Widget>.generate(items.length, (i) {
          final selected = i == controller.currentTypeIndex;
          final double dotSize = 14.w;
          
          // 导航点
          final Widget dot = RepaintBoundary(
            child: SizedBox(
              width: maxBox,
              height: maxBox,
              child: Center(
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: CustomAppColors.primary,
                      width: 2.w,
                    ),
                  ),
                ),
              ),
            ),
          );
          
          // 文字标签 - 使用 AnimatedDefaultTextStyle 实现平滑过渡
          final label = AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: selected ? 36.sp : 26.sp,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? CustomAppColors.primary : CustomAppColors.subText,
            ),
            child: Text(items[i]),
          );
          
          final isFirst = i == 0;
          final isLast = i == items.length - 1;
          final isOnly = items.length == 1;
          final factor = isOnly ? 0.0 : ((isFirst || isLast) ? 0.5 : 1.0);
          
          // 使用标准的 Row Widget
          final navRow = Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: label,
                  ),
                ),
                SizedBox(width: 0.w),
                dot,
              ],
            ),
          );
          
          final rowStack = GestureDetector(
            onTap: () => controller.scrollToSection(i),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // 连接线
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.only(right: baseCenterX),
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
                navRow,
              ],
            ),
          );
          
          // 使用标准的 Expanded Widget
          return Expanded(
            child: Container(
              key: controller.navItemKeys[i],
              child: rowStack,
            ),
          );
        });
        
        // 使用标准的 Column Widget
        final navColumn = RepaintBoundary(
          child: Container(
            width: 240.w,
            height: 808.h,
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
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
                    curve: Curves.easeOutCubic,
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
}
