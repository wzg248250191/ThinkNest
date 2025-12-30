import 'package:flutter/material.dart';
import 'dart:math' as math;
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
  /// 构建单个课程卡片
  /// 说明：
  /// - 外层尺寸由网格决定（SliverGrid 的 childAspectRatio 等）
  /// - 这里通过 LayoutBuilder 按实际可用宽高动态缩放图片区域，避免不同屏幕尺寸下发生溢出
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;

            final imageSide = math.min(maxW, maxH * 0.66);

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: imageSide,
                  height: imageSide,
                  child: _buildImageArea(context, imgPath, side: imageSide),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 0.h),
                  child: _buildInfoText('推荐班级：', recommendedClass),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: _buildInfoText('重点领域：', decoration),
                ),
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
            );
          },
        ),
      ),
    );
  }

  /// 构建课程图片区域
  /// [side] 为当前卡片可用尺寸下计算出的图片边长，用于自适应不同分辨率
  /// 同时根据 [side] 限制图片解码尺寸，减少内存与卡顿
  Widget _buildImageArea(BuildContext context, String imgPath, {required double side}) {
    // 🚀 计算实际需要的图片尺寸，限制解码大小减少内存
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (side * dpr).round();
    
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageWidget.svg(
            _svgBgPath,
            width: side * 0.76,
            height: side * 0.76,
            fit: BoxFit.cover,
          ),
          Image.asset(
            imgPath,
            width: side,
            height: side,
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

  /// 构建“标签 + 值”的信息文本行
  /// 说明：
  /// - 固定单行显示并省略，避免小屏/窄屏时换行导致卡片高度溢出
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
