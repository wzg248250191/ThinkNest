import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'index.dart';

class LogsPage extends GetView<LogsController> {
  const LogsPage({super.key});

  /// 构建“近3天”日期切换栏
  Widget _buildDayTabs() {
    const double outerButtonWidth = 150;
    const double outerButtonHeight = 52;

    // 构建单个日期标签按钮
    Widget buildTab(String text, int offset) {
      final active = controller.dayOffset == offset;
      return GestureDetector(
        onTap: () => controller.selectDayOffset(offset),
        child: Container(
          width: outerButtonWidth.w,
          height: outerButtonHeight.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? CustomAppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: CustomAppColors.border),
          ),
          child: TextWidget.label(
            text,
            fontSize: 22.sp,
            color: active ? Colors.white : CustomAppColors.text,
          ),
        ),
      );
    }

    return <Widget>[
      buildTab('今天', 0),
      SizedBox(width: 10.w),
      buildTab('昨天', 1),
      SizedBox(width: 10.w),
      buildTab('前天', 2),
    ].toRow(mainAxisSize: MainAxisSize.min);
  }

  /// 构建日志类型筛选栏：全部/错误/打印
  Widget _buildFilters() {
    return GetBuilder<LogsController>(
      id: 'logs_filters',
      builder: (_) {
        return ExclusiveButtonGroup(
          // 关键：顶部功能条要求“所有按钮视觉尺寸一致”，这里与日期/操作按钮保持一致
          labels: const ['全部', '错误', '打印'],
          selectedIndex: controller.filterIndex,
          onSelected: controller.selectFilterIndex,
          buttonWidth: 150.w,
          buttonHeight: 52.h,
          groupRadius: 14.r,
          fontSize: 22.sp,
          borderWidth: 1.w,
        );
      },
    );
  }

  /// 构建顶部操作栏：普通态（导出/加载更多）与多选态（复制/导出/取消）
  Widget _buildActions() {
    return GetBuilder<LogsController>(
      id: 'logs_actions',
      builder: (_) {
        const double outerButtonWidth = 150;
        const double outerButtonHeight = 52;
        const double buttonFontSize = 20;
        const double innerButtonWidth = outerButtonWidth - 16;
        const double innerButtonHeight = outerButtonHeight - 8;

        if (!controller.selectionMode) {
          return <Widget>[
            ButtonWidget.primary(
              '导出当天',
              onTap: controller.exportDay,
              scale: WidgetScale.medium,
              fontSize: buttonFontSize.sp,
              width: innerButtonWidth.w,
              height: innerButtonHeight.h,
            ),
            SizedBox(width: 10.w),
            ButtonWidget.secondary(
              '加载更多',
              onTap: controller.loadMore,
              scale: WidgetScale.medium,
              fontSize: buttonFontSize.sp,
              width: innerButtonWidth.w,
              height: innerButtonHeight.h,
            ),
            SizedBox(width: 10.w),
            ButtonWidget.destructive(
              '清除当天',
              onTap: controller.clearCurrentDay,
              scale: WidgetScale.medium,
              fontSize: buttonFontSize.sp,
              width: innerButtonWidth.w,
              height: innerButtonHeight.h,
            ),
          ].toRow(mainAxisSize: MainAxisSize.min);
        }

        return <Widget>[
          ButtonWidget.secondary(
            '已选${controller.selectedIndexes.length}',
            scale: WidgetScale.medium,
            fontSize: buttonFontSize.sp,
            width: innerButtonWidth.w,
            height: innerButtonHeight.h,
          ),
          SizedBox(width: 10.w),
          ButtonWidget.primary(
            '复制',
            onTap: controller.copySelected,
            scale: WidgetScale.medium,
            fontSize: buttonFontSize.sp,
            width: innerButtonWidth.w,
            height: innerButtonHeight.h,
          ),
          SizedBox(width: 10.w),
          ButtonWidget.secondary(
            '导出',
            onTap: controller.exportSelected,
            scale: WidgetScale.medium,
            fontSize: buttonFontSize.sp,
            width: innerButtonWidth.w,
            height: innerButtonHeight.h,
          ),
          SizedBox(width: 10.w),
          ButtonWidget.secondary(
            '取消',
            onTap: controller.exitSelectionMode,
            scale: WidgetScale.medium,
            fontSize: buttonFontSize.sp,
            width: innerButtonWidth.w,
            height: innerButtonHeight.h,
          ),
        ].toRow(mainAxisSize: MainAxisSize.min);
      },
    );
  }

  /// 根据日志类型返回左侧标识色
  Color _typeColor(AppLogType type) {
    if (type == AppLogType.error) {
      return Colors.red;
    }
    return CustomAppColors.primary;
  }

  /// 将日志类型转换为展示文本
  String _typeText(AppLogType type) {
    if (type == AppLogType.error) return 'ERROR';
    return 'PRINT';
  }

  /// 打开日志详情弹窗，展示单条完整文本
  Future<void> _openDetail(AppLogLine line) async {
    final content = '${line.timestamp.toIso8601String()} [${_typeText(line.type)}] ${line.message}';
    await Get.dialog(
      AlertDialog(
        title: TextWidget.label('日志详情', fontSize: 28.sp),
        content: SizedBox(
          width: 1400.w,
          child: SingleChildScrollView(
            child: TextWidget.label(content, fontSize: 22.sp),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: TextWidget.label('关闭', fontSize: 24.sp),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  /// 构建日志列表区域（包含空态与加载态）
  Widget _buildList() {
    return GetBuilder<LogsController>(
      id: 'logs',
      builder: (_) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = controller.displayItems;
        if (controller.lines.isEmpty) {
          return Center(
            child: TextWidget.label(
              '${controller.selectedDayLabel}暂无日志',
              fontSize: 26.sp,
              color: CustomAppColors.text.withValues(alpha: 0.6),
            ),
          );
        }
        if (items.isEmpty) {
          return Center(
            child: TextWidget.label(
              '暂无符合筛选的日志',
              fontSize: 26.sp,
              color: CustomAppColors.text.withValues(alpha: 0.6),
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
          itemBuilder: (context, index) {
            final item = items[index];
            final line = item.line;
            final selected = controller.selectedIndexes.contains(item.sourceIndex);
            return GestureDetector(
              onLongPress: () => controller.enterSelectionMode(item.sourceIndex),
              onTap: () {
                if (controller.selectionMode) {
                  controller.toggleSelected(item.sourceIndex);
                  return;
                }
                _openDetail(line);
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 14.h),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: selected ? CustomAppColors.primary.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: selected ? CustomAppColors.primary : CustomAppColors.border,
                  ),
                ),
                child: <Widget>[
                  Container(
                    width: 8.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: _typeColor(line.type),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: <Widget>[
                      TextWidget.label(
                        '${line.timestamp.hour.toString().padLeft(2, '0')}:${line.timestamp.minute.toString().padLeft(2, '0')}:${line.timestamp.second.toString().padLeft(2, '0')}  ${_typeText(line.type)}',
                        fontSize: 22.sp,
                        color: CustomAppColors.text.withValues(alpha: 0.75),
                      ),
                      SizedBox(height: 6.h),
                      TextWidget.label(
                        line.message,
                        fontSize: 24.sp,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ].toColumn(crossAxisAlignment: CrossAxisAlignment.start),
                  ),
                  if (controller.selectionMode)
                    Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? CustomAppColors.primary : CustomAppColors.text.withValues(alpha: 0.35),
                      size: 30.sp,
                    ),
                ].toRow(crossAxisAlignment: CrossAxisAlignment.start),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建页面主体布局
  Widget _buildView() {
    final BoxDecoration groupDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: CustomAppColors.border),
    );

    return <Widget>[
      SizedBox(height: 12.h),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: <Widget>[
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: groupDecoration,
            child: GetBuilder<LogsController>(
              id: 'logs_day_tabs',
              builder: (_) => _buildDayTabs(),
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: groupDecoration,
            child: _buildFilters(),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: groupDecoration,
            child: _buildActions(),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: groupDecoration.copyWith(borderRadius: BorderRadius.circular(999.r)),
            child: GetBuilder<LogsController>(
              id: 'socket_log_switch',
              builder: (_) {
                final enabled = DebugUtils.socketLogEnabled;
                return <Widget>[
                  TextWidget.label(
                    'Socket',
                    fontSize: 20.sp,
                    color: CustomAppColors.text.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: 8.w),
                  Switch(
                    value: enabled,
                    activeThumbColor: CustomAppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) {
                      DebugUtils.setSocketLogEnabled(value).then((_) => controller.update(['socket_log_switch']));
                    },
                  ),
                ].toRow(mainAxisSize: MainAxisSize.min);
              },
            ),
          ),
        ].toRow(mainAxisSize: MainAxisSize.min),
      ),
      SizedBox(height: 12.h),
      Expanded(child: _buildList()),
    ].toColumn();
  }

  @override
  /// 构建日志页面：提供近3天切换与多选导出能力
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(
        title: '日志',
        isBack: true,
        onTap: () => Get.back(),
      ),
      body: _buildView(),
    );
  }
}
