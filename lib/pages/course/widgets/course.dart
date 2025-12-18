import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../../../common/index.dart';

class CourseWidget extends StatelessWidget {
  const CourseWidget({super.key, required this.name, this.onTap});

  final String name;
  final Function()? onTap;

  // 静态常量样式，避免重复创建
  static const _labelStyle = TextStyle(color: Colors.black);
  static const _valueStyle = TextStyle(color: CustomAppColors.primary);
  static const _svgBgPath = 'assets/svgs/CourseBg.svg';

  @override
  Widget build(BuildContext context) {
    final m = coursesByName[name];
    final String imgPath = 'assets/images/courses/$name.png';
    final String decoration = (m?['describe'] as String?) ?? '';
    final String recommendedClass = (m?['class'] as String?) ?? '全部班级';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CustomAppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 图片区域
            _buildImageArea(context, imgPath),
            // 推荐班级
            Padding(
              padding: EdgeInsets.only(top: 0.h),
              child: _buildInfoText('推荐班级：', recommendedClass),
            ),
            // 重点领域
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: _buildInfoText('重点领域：', decoration),
            ),
            // 课程名称
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w400,
                ),
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

  Widget _buildImageArea(BuildContext context, String imgPath) {
    // 🚀 计算实际需要的图片尺寸，限制解码大小减少内存
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (210 * dpr).round();
    
    return SizedBox(
      width: 210.w,
      height: 210.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageWidget.svg(
            _svgBgPath,
            width: 160.w,
            height: 160.h,
            fit: BoxFit.cover,
          ),
          Image.asset(
            imgPath,
            width: 210.w,
            height: 210.h,
            fit: BoxFit.cover,
            // 🚀 限制解码尺寸，减少内存占用
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            // 🚀 图片切换时不闪烁
            gaplessPlayback: true,
            // 🚀 低质量滤镜，提升渲染速度
            filterQuality: FilterQuality.low,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Text.rich(
      TextSpan(
        text: label,
        style: _labelStyle,
        children: [
          TextSpan(text: value, style: _valueStyle),
        ],
      ),
      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w400),
      textAlign: TextAlign.center,
    );
  }
}
