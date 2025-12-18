import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import '../../../common/index.dart';
import 'course.dart' as cw;

Map<String, String> courseType = {
  '智慧之力': 'LOGICAL-MATHEMATICAL',
  '自然之谜': 'NATURALIST',
  '创想之光': 'SPATIAL',
  '音乐之声': 'MUSICAL',
  '内省之智': 'INTRAPERSONAL',
  '运动之星': 'BODILY-KINESTHETIC',
  '童梦之语': 'LINGUISTIC',
  '人际之行': 'INTERPERSONAL',
  '安全之盾': 'SECURE',
};

/// 课程分类 Section - 使用帧调度的渐进式加载
/// 首帧只渲染一行(5个)，后续在空闲帧逐步加载更多，避免首次渲染卡顿
class CourseTypeSection extends StatefulWidget {
  const CourseTypeSection({
    super.key,
    required this.typeName,
    this.names,
    this.onCourseTap,
  });

  final String typeName;
  final List<String>? names;
  final void Function(String name)? onCourseTap;

  @override
  State<CourseTypeSection> createState() => _CourseTypeSectionState();
}

class _CourseTypeSectionState extends State<CourseTypeSection> {
  late List<String> _list;
  int _displayCount = 0;
  bool _fullyLoaded = false;

  // 每行5个，首次显示1行
  static const int _itemsPerRow = 5;
  static const int _initialRows = 1;
  static const int _rowsPerFrame = 2; // 每帧加载2行

  @override
  void initState() {
    super.initState();
    _initList();
  }

  @override
  void didUpdateWidget(covariant CourseTypeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.names != widget.names || oldWidget.typeName != widget.typeName) {
      _initList();
    }
  }

  void _initList() {
    _list = widget.names ??
        coursesByName.entries
            .where((e) => e.value['type'] == widget.typeName)
            .map((e) => e.key)
            .toList();
    
    // 首帧显示的数量
    _displayCount = (_itemsPerRow * _initialRows).clamp(0, _list.length);
    _fullyLoaded = _displayCount >= _list.length;
    
    if (!_fullyLoaded) {
      // 使用 postFrameCallback 在下一帧继续加载
      SchedulerBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
  }

  void _loadMore() {
    if (!mounted || _fullyLoaded) return;
    
    final int nextCount = (_displayCount + _itemsPerRow * _rowsPerFrame).clamp(0, _list.length);
    
    if (nextCount > _displayCount) {
      setState(() {
        _displayCount = nextCount;
        _fullyLoaded = _displayCount >= _list.length;
      });
    }
    
    if (!_fullyLoaded) {
      // 继续在下一帧加载
      SchedulerBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = courseType[widget.typeName] ?? (widget.typeName == '童梦之语' ? 'LINGUISTIC' : '');
    final double crossAxisSpacing = 46.w;
    final double mainAxisSpacing = 46.h;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题部分
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.typeName,
                    style: const TextStyle(color: CustomAppColors.primary),
                  ),
                  const TextSpan(text: '/'),
                  TextSpan(
                    text: en,
                    style: const TextStyle(color: CustomAppColors.subText),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w600),
            ),
          ),
          // 课程网格
          _buildCourseGrid(crossAxisSpacing, mainAxisSpacing),
        ],
      ),
    );
  }

  Widget _buildCourseGrid(double crossAxisSpacing, double mainAxisSpacing) {
    final double itemWidth = 238.w;
    final double itemHeight = 320.h;

    return Wrap(
      spacing: crossAxisSpacing,
      runSpacing: mainAxisSpacing,
      children: List.generate(_displayCount, (index) {
        final n = _list[index];
        return RepaintBoundary(
          child: SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: cw.CourseWidget(
              key: ValueKey('course_${widget.typeName}_$n'),
              name: n,
              onTap: () => widget.onCourseTap?.call(n),
            ),
          ),
        );
      }),
    );
  }
}
