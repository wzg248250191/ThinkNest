import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../index.dart';
import '../../../common/index.dart';

class CourseNavWidget extends GetView<CourseController> {
  const CourseNavWidget({super.key});

  // 导航行高常量
  static double get _rowHeight => 64.h;

  @override
  Widget build(BuildContext context) { 
    return <Widget>[
      _buildName().paddingRight(16.w),
      _buildRight(),
    ].toRow(mainAxisAlignment: MainAxisAlignment.center);
  }

  /// 构建分类名
  Widget _buildName() {
    return GetBuilder<CourseController>(
      id: 'course_nav_name',
      builder: (_) {
        final items = controller.types;
        final navNames = List<Widget>.generate(items.length, (index) {
          final bool selected = controller.currentTypeIndex == index;
          return GestureDetector(
            onTap: () => controller.scrollToSection(index),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: _rowHeight,
              width: 160.w,
              child: Align(
                alignment: Alignment.centerRight,
                child: RepaintBoundary(
                  child: AnimatedScale(
                    scale: selected ? (36.sp / 26.sp) : 1.0,
                    duration: Duration(milliseconds: controller.navAnimDurationMs),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child: AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: controller.navAnimDurationMs),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w600,
                        color: selected ? CustomAppColors.primary : CustomAppColors.subText,
                      ),
                      child: Text(items[index]),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
        return navNames.toColumn(        
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
        );
      },
    );
  }

  Widget _buildRight()
  {
    return Container(
      key: controller.navContainerKey,
      child: Stack(
        children: [
          _buildLine(),
          _buildDot(),
          _buildPulseDot(),
        ],
      ),
    );
  }
  /// 构建空心圆点
  Widget _buildDot() {
    final items = controller.types;
    List<Widget> dots = List<Widget>.generate(items.length, (index) {
      return SizedBox(
        height: _rowHeight,
        child: Center(
          child: DotWidget(
            key: controller.dotKeys[index],
            size: 14.w,      
            color: CustomAppColors.primary,
            borderWidth: 2,   
          ),
        ),
      );
    });
    return dots.toColumn(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
 }

 Widget _buildLine()
 {
    return GetBuilder<CourseController>(
      id: 'course_nav_line',
      builder: (_) {
        final centers = controller.navCenters;
        if (centers.isEmpty) {
          return const SizedBox.shrink();
        }
        final double dotSize = 14.w;
        final double firstCenter = centers.first;
        final double lastCenter = centers.last;
        final double top = firstCenter + dotSize / 2;
        final double bottom = lastCenter - dotSize / 2;
        final double height = (bottom - top).clamp(0, double.infinity);
        if (height <= 0) {
          return const SizedBox.shrink();
        }
        final double lineWidth = 2.w;
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: lineWidth,
              height: height,
              color: CustomAppColors.primary.withValues(alpha: 0.25),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulseDot() {
    return GetBuilder<CourseController>(
      id: 'course_nav_overlay',
      builder: (_) {
        final double selectedSize = 21.w;
        final double slideY =
            (controller.overlayCenterY - selectedSize / 2) / selectedSize;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: IgnorePointer(
              child: AnimatedSlide(
                offset: Offset(0, slideY),
                duration: Duration(milliseconds: controller.navAnimDurationMs),
                curve: Curves.easeOutCubic,
                child: Center(
                  child: PulseDot(
                    size: selectedSize,
                    color: CustomAppColors.primary,
                    enabled: !controller.isNavAnimating,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DotWidget extends StatelessWidget {
  final double size;
  final Color color;
  final double borderWidth;
  const DotWidget({
    super.key,
    required this.size,
    required this.color,
    this.borderWidth = 2,
  });
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: color,
            width: borderWidth.w,
          ),
        ),
      ),
    );
  }
}
