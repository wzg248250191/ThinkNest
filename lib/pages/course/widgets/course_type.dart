import 'package:flutter/material.dart';
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

class CourseTypeSection extends StatelessWidget {
  const CourseTypeSection({super.key, required this.typeName, this.onCourseTap});

  final String typeName;
  final void Function(String name)? onCourseTap;

  @override
  Widget build(BuildContext context) {
    
    final en = courseType[typeName] ?? (typeName == '童梦之语' ? 'LINGUISTIC' : '');
    final names = coursesByName.entries
        .where((e) => e.value['type'] == typeName)
        .map((e) => e.key)
        .toList();

    // 使用 RepaintBoundary 隔离标题和网格的重绘
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题部分使用 RepaintBoundary
          RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: typeName,
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
          ),
          // 使用 GridView.builder 的优化版本
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 46.w,
              mainAxisSpacing: 46.h,
              childAspectRatio: 238 / 320,
            ),
            itemCount: names.length,
            itemBuilder: (context, index) {
              final n = names[index];
              // 为每个课程添加 RepaintBoundary，避免互相影响
              return RepaintBoundary(
                child: cw.CourseWidget(
                  key: ValueKey('course_${typeName}_$n'),
                  name: n,
                  onTap: () => onCourseTap?.call(n),
                ),
              );
            },
            // 添加缓存范围，提高滚动性能
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: false, // 我们手动添加了
          ),
        ],
      ),
    );
  }
}
