import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../../../common/index.dart';

class CourseWidget extends StatelessWidget {
  const CourseWidget({
    super.key,
    required this.name,
    this.onTap,
  });

  final String name;
  final Function()? onTap;

  // 静态常量样式，避免重复创建
  static const _labelStyle = TextStyle(color: Colors.black);
  static const _valueStyle = TextStyle(color: CustomAppColors.primary);
  static const _bgPath = AssetsImages.courseBgPng;

  @override
  /// 构建单个课程卡片
  /// 说明：
  /// - 外层尺寸由网格决定（SliverGrid 的 childAspectRatio 等）
  /// - 这里通过 LayoutBuilder 按实际可用宽高动态缩放图片区域，避免不同屏幕尺寸下发生溢出
  Widget build(BuildContext context) {
    final m = coursesByName[name];
    // 课程封面可能因历史目录大小写/扩展名差异导致加载失败，这里做多候选回退
    final List<String> coverCandidates = <String>[
      '${AssetsImages.courseCoversDir}$name.png',
      'assets/images/courses/$name.png',
      '${AssetsImages.courseCoversDir}$name.PNG',
      'assets/images/courses/$name.PNG',
    ];
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

            return <Widget>[
              SizedBox(
                width: imageSide,
                height: imageSide,
                child: _buildImageArea(
                  context,
                  coverCandidates,
                  side: imageSide,
                ),
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
            ].toColumn(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
            );
          },
        ),
      ),
    );
  }

  /// 构建课程图片区域
  /// [side] 为当前卡片可用尺寸下计算出的图片边长，用于自适应不同分辨率
  /// 同时根据 [side] 限制图片解码尺寸，减少内存与卡顿
  /// [coverCandidates] 为封面路径候选列表，按顺序尝试加载，避免单一路径不一致导致“无图”
  Widget _buildImageArea(
    BuildContext context,
    List<String> coverCandidates, {
    required double side,
  }) {
    // 计算实际需要的图片尺寸，限制解码大小减少内存
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final int cacheSize = (side * dpr).round().clamp(1, 4096);

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _bgPath,
            width: side * 0.76,
            height: side * 0.76,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
          _buildCoverImage(
            coverCandidates: coverCandidates,
            side: side,
            cacheSize: cacheSize,
          ),
        ],
      ),
    );
  }

  /// 构建封面图片（多候选回退）
  /// 说明：
  /// - assets 文件/目录名在不同平台上可能存在大小写敏感差异
  /// - 这里按候选顺序逐个尝试，直到加载成功；全部失败则不显示封面
  Widget _buildCoverImage({
    required List<String> coverCandidates,
    required double side,
    required int cacheSize,
  }) {
    if (coverCandidates.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildAt(int index) {
      if (index >= coverCandidates.length) {
        return const SizedBox.shrink();
      }
      final String path = coverCandidates[index];
      return Image.asset(
        path,
        width: side,
        height: side,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => buildAt(index + 1),
      );
    }

    return buildAt(0);
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
