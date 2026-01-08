import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:think_nest/common/index.dart';
import 'package:think_nest/pages/index.dart';


/// 课程列表页悬浮窗组件
/// 显示当前正在运行的课程信息，点击可快速跳转
class FloatingCourseWidget extends StatelessWidget {
  const FloatingCourseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<PcCourseMessageHandler>(
      builder: (handler) {
        final activeId = handler.currentCourseId.value;
        final isRunning = handler.wallCourseEnabled.value || handler.deskCourseEnabled.value;

        // 只有当有课程运行，才显示悬浮窗
        if (isRunning && activeId != null) {
          final Color base = CustomAppColors.primary;
          final Color shadowColor = Colors.black.withValues(alpha: 0.16);

          return Positioned(
            top: 18.h,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (Get.isRegistered<MainController>()) {
                      Get.find<MainController>().openCourseController(activeId);
                    }
                  },
                  borderRadius: BorderRadius.circular(999.r),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.resolveWith(
                    (states) => Colors.white.withValues(alpha: 0.10),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    constraints: BoxConstraints(maxWidth: 420.w),
                    decoration: BoxDecoration(
                      color: base.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.w),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: <Widget>[
                      _buildCourseIcon(activeId),
                      SizedBox(width: 10.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 260.w),
                        child: Text(
                          activeId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.90), size: 20.sp),
                    ].toRow(crossAxisAlignment: CrossAxisAlignment.center),
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// 构建课程图标
  /// 说明：
  /// - 优先使用课程封面图片
  /// - 若封面路径因大小写/扩展名不一致导致加载失败，则回退为默认图标
  Widget _buildCourseIcon(String courseName) {
    final List<String> coverCandidates = <String>[
      '${AssetsImages.courseCoversDir}$courseName.png',
      'assets/images/courses/$courseName.png',
      '${AssetsImages.courseCoversDir}$courseName.PNG',
      'assets/images/courses/$courseName.PNG',
    ];

    return Container(
      width: 50.w,
      height: 50.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.w),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white.withValues(alpha: 0.08),
        child: _buildCoverImage(coverCandidates),
      ),
    );
  }

  /// 构建封面图片（多候选回退）
  /// 说明：悬浮窗面积较小，这里不做额外解码尺寸限制，减少分支复杂度
  Widget _buildCoverImage(List<String> coverCandidates) {
    if (coverCandidates.isEmpty) {
      return _buildFallbackIcon();
    }

    Widget buildAt(int index) {
      if (index >= coverCandidates.length) {
        return _buildFallbackIcon();
      }
      return Image.asset(
        coverCandidates[index],
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => buildAt(index + 1),
      );
    }

    return buildAt(0);
  }

  /// 构建封面缺失时的默认图标
  Widget _buildFallbackIcon() {
    return Icon(
      Icons.menu_book_rounded,
      color: Colors.white.withValues(alpha: 0.92),
      size: 20.sp,
    );
  }
}
