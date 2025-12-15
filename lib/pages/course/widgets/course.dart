import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../../../common/index.dart';

class CourseWidget extends StatelessWidget {
 const CourseWidget({super.key, required this.name, this.onTap});

final String name;
final Function()? onTap;
  @override
  Widget build(BuildContext context) {

    //得到课程信息
    final m = coursesByName[name];
    //图片地址
    final String imgPath = 'assets/images/courses/$name.png';
    //重点领域
    final String decoration = (m?['describe'] as String?) ?? '';
    //推荐班级
    final String recommendedClass = (m?['class'] as String?) ?? '全部班级';
    final String bgSvgPath = 'assets/svgs/CourseBg.svg';

    final Widget imageArea = Stack(
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
    );

    final Widget content = <Widget>[
      imageArea,
      Text.rich(
        TextSpan(
          text: '推荐班级：',
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(
              text: recommendedClass,
              style: const TextStyle(color: CustomAppColors.primary),
            ),
          ],
        ),
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400),
        textAlign: TextAlign.center,
      ).paddingTop(0.h),
      Text.rich(
        TextSpan(
          text: '重点领域：',
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(
              text: decoration,
              style: const TextStyle(color: CustomAppColors.primary),
            ),
          ],
        ),
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400),
        textAlign: TextAlign.center,
      ).paddingTop(4.h),
      TextWidget.body(
        name,
        size: 26.sp,
        weight: FontWeight.w400,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ).paddingTop(8.h),
    ]
        .toColumn(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
        )
        .padding(horizontal: 2.w, vertical: 2.w)
        .constrained(width: 238.w, height: 320.h) // 固定卡片尺寸，宽238高400，确保卡片布局一致
        .decorated(
          color:CustomAppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        )
        .onTap(onTap);

    return content;
  }
}
