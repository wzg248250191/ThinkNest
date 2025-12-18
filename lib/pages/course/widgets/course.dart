import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../common/index.dart';

/// 共享的 SVG 背景 - 避免每个卡片重复解析 SVG
class _CourseBgCache {
  static final _CourseBgCache _instance = _CourseBgCache._();
  factory _CourseBgCache() => _instance;
  _CourseBgCache._();
  
  SvgPicture? _cachedBg;
  double? _cachedWidth;
  double? _cachedHeight;
  
  Widget getBg(double width, double height) {
    // 只有尺寸变化时才重新创建
    if (_cachedBg == null || _cachedWidth != width || _cachedHeight != height) {
      _cachedWidth = width;
      _cachedHeight = height;
      _cachedBg = SvgPicture.asset(
        'assets/svgs/CourseBg.svg',
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return _cachedBg!;
  }
}

class CourseWidget extends StatelessWidget {
  const CourseWidget({super.key, required this.name, this.onTap});

  final String name;
  final Function()? onTap;
  
  // 静态常量样式，避免重复创建
  static const _blackStyle = TextStyle(color: Colors.black);
  static const _primaryStyle = TextStyle(color: CustomAppColors.primary);
  
  @override
  Widget build(BuildContext context) {
    // 得到课程信息
    final m = coursesByName[name];
    // 图片地址
    final String imgPath = 'assets/images/courses/$name.png';
    // 重点领域
    final String decoration = (m?['describe'] as String?) ?? '';
    // 推荐班级
    final String recommendedClass = (m?['class'] as String?) ?? '全部班级';

    // 预计算尺寸
    final double bgWidth = 160.w;
    final double bgHeight = 160.h;
    final double imgWidth = 210.w;
    final double imgHeight = 210.h;

    // 使用缓存的 SVG 背景
    final bgWidget = _CourseBgCache().getBg(bgWidth, bgHeight);

    // 图片区域
    final Widget imageArea = RepaintBoundary(
      child: SizedBox(
        width: imgWidth,
        height: imgHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            bgWidget,
            ImageWidget.img(
              imgPath,
              width: imgWidth,
              height: imgHeight,
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );

    final textStyle = TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 238.w,
        height: 320.h,
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.w),
        decoration: BoxDecoration(
          color: CustomAppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            imageArea,
            Padding(
              padding: EdgeInsets.only(top: 0.h),
              child: Text.rich(
                TextSpan(
                  text: '推荐班级：',
                  style: _blackStyle,
                  children: [
                    TextSpan(
                      text: recommendedClass,
                      style: _primaryStyle,
                    ),
                  ],
                ),
                style: textStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text.rich(
                TextSpan(
                  text: '重点领域：',
                  style: _blackStyle,
                  children: [
                    TextSpan(
                      text: decoration,
                      style: _primaryStyle,
                    ),
                  ],
                ),
                style: textStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: TextWidget.body(
                name,
                size: 26.sp,
                weight: FontWeight.w400,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
