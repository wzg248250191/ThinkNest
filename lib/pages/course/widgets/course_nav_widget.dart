import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../index.dart';
import '../../../common/index.dart';

class CourseNavWidget extends GetView<CourseController> {
  const CourseNavWidget({super.key});

  @override
  /// 构建课程右侧分类导航（名称列 + 圆点列）
  Widget build(BuildContext context) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gap = 2.w;
        final double selectedSize = 21.w;
        final double rightWidth = selectedSize;

        final double maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : (gap + 160.w + rightWidth);
        final double nameWidth = (maxWidth - rightWidth - gap).clamp(60.w, maxWidth);

        return <Widget>[
          SizedBox(width: nameWidth, child: _buildName(nameWidth)).paddingRight(gap),
          SizedBox(width: rightWidth, child: _buildRight()),
        ].toRow(mainAxisAlignment: MainAxisAlignment.center);
      },
    );
  }

  /// 构建分类名
  Widget _buildName(double itemWidth) {
    return GetBuilder<CourseController>(
      id: 'course_nav_name',
      builder: (_) {
        final items = controller.types;
        final navNames = List<Widget>.generate(items.length, (index) {
          final bool selected = controller.currentTypeIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.scrollToSection(index),
              behavior: HitTestBehavior.opaque,
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
                      child: SizedBox(
                        width: itemWidth,
                        child: Text(
                          items[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
        return navNames.toColumn(        
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
        );
      },
    );
  }

  /// 构建右侧圆点导航（包含连线、空心点、脉冲选中点）
  ///
  /// 说明：
  /// - 某些布局场景下（例如父级未约束高度），Stack 会收到无限高度约束并触发
  ///   RenderStack 的 size.isFinite 断言失败
  /// - 这里在检测到“高度不受限”时提供一个合理的兜底高度，确保首次帧能正常渲染，
  ///   避免 Windows 端窗口因首帧异常而不显示
  Widget _buildRight() {
    final count = controller.types.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (count <= 0) {
          return const SizedBox.shrink();
        }

        final bool hasFiniteHeight = constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final double fallbackHeight = (count * 56.h).clamp(140.h, 980.h);
        final double height = hasFiniteHeight ? constraints.maxHeight : fallbackHeight;
        if (height <= 0 || !height.isFinite) {
          return const SizedBox.shrink();
        }

        final double dotSize = 14.w;
        final double selectedSize = 21.w;

        final bool hasFiniteWidth = constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final double fallbackWidth = selectedSize;
        final double width = hasFiniteWidth ? constraints.maxWidth : fallbackWidth;

        final centers = List<double>.generate(count, (index) => height * (index + 0.5) / count);
        final double lineWidth = 2.w;

        final List<Widget> children = [];

        if (count > 1) {
          final double firstCenter = centers.first;
          final double lastCenter = centers.last;
          final double top = firstCenter + dotSize / 2;
          final double bottom = lastCenter - dotSize / 2;
          final double lineHeight = (bottom - top).clamp(0, double.infinity);
          if (lineHeight > 0) {
            children.add(
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: lineWidth,
                    height: lineHeight,
                    color: CustomAppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
              ),
            );
          }
        }

        for (final centerY in centers) {
          children.add(
            Positioned(
              top: centerY - dotSize / 2,
              left: 0,
              right: 0,
              height: dotSize,
              child: Center(
                child: DotWidget(
                  size: dotSize,
                  color: CustomAppColors.primary,
                  borderWidth: 2,
                ),
              ),
            ),
          );
        }

        children.add(_buildPulseDot(centers));

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }

  /// 构建脉冲选中点（随分类变化做位移动画）
  Widget _buildPulseDot(List<double> centers) {
    return GetBuilder<CourseController>(
      id: 'course_nav_overlay',
      builder: (_) {
        final double selectedSize = 21.w;
        final int count = centers.length;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        final int maxIndex = count - 1;
        final int index = controller.currentTypeIndex.clamp(0, maxIndex);
        final double centerY = centers[index];

        return AnimatedPositioned(
          duration: Duration(milliseconds: controller.navAnimDurationMs),
          curve: Curves.easeInOutCubicEmphasized,
          top: centerY - selectedSize / 2,
          left: 0,
          right: 0,
          height: selectedSize,
          child: RepaintBoundary(
            child: IgnorePointer(
              child: Center(
                child: PulseDot(
                  size: selectedSize,
                  color: CustomAppColors.primary,
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
