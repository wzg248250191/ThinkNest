import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../../../common/index.dart';

class CourseWidget extends StatelessWidget {
  const CourseWidget({super.key, required this.name, this.onTap});

  final String name;
  final Function()? onTap;
  
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
    final String bgSvgPath = 'assets/svgs/CourseBg.svg';

    // 图片区域使用 RepaintBoundary 隔离
    final Widget imageArea = RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageWidget.svg(
            bgSvgPath,
            width: 160.w,
            height: 160.h,
            fit: BoxFit.cover,
          ),
          ImageWidget.img(
            imgPath,
            width: 210.w,
            height: 210.h,
            fit: BoxFit.cover,
          ),
        ],
      ),
    );

    // 优化文字样式，减少重复创建
    final textStyle = TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400);
    const blackStyle = TextStyle(color: Colors.black);
    const primaryStyle = TextStyle(color: CustomAppColors.primary);

    // 使用标准的 Flutter Widget
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
                  style: blackStyle,
                  children: [
                    TextSpan(
                      text: recommendedClass,
                      style: primaryStyle,
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
                  style: blackStyle,
                  children: [
                    TextSpan(
                      text: decoration,
                      style: primaryStyle,
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
