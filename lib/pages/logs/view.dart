import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart' hide AlertDialog;

import 'index.dart';

class LogsPage extends GetView<LogsController> {
  const LogsPage({super.key});

  /// 构建“近3天”日期切换栏
  Widget _buildDayTabs() {
    // 构建单个日期标签按钮
    Widget buildTab(String text, int offset) {
      final active = controller.dayOffset == offset;
      return GestureDetector(
        onTap: () => controller.selectDayOffset(offset),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: active ? CustomAppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: CustomAppColors.border),
          ),
          child: TextWidget.label(
            text,
            fontSize: 24.sp,
            color: active ? Colors.white : CustomAppColors.text,
          ),
        ),
      );
    }

    return <Widget>[
      buildTab('今天', 0),
      SizedBox(width: 16.w),
      buildTab('昨天', 1),
      SizedBox(width: 16.w),
      buildTab('前天', 2),
    ].toRow(mainAxisAlignment: MainAxisAlignment.center);
  }

  /// 构建日志类型筛选栏：全部/错误/打印
  Widget _buildFilters() {
    return GetBuilder<LogsController>(
      id: 'logs_filters',
      builder: (_) {
        return ExclusiveButtonGroup(
          labels: const ['全部', '错误', '打印'],
          selectedIndex: controller.filterIndex,
          onSelected: controller.selectFilterIndex,
          buttonWidth: 160.w,
          buttonHeight: 60.h,
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
        if (!controller.selectionMode) {
          return <Widget>[
            ButtonWidget.primary(
              '导出当天',
              onTap: controller.exportDay,
              width: 220.w,
              height: 70.h,
            ),
            SizedBox(width: 16.w),
            ButtonWidget.secondary(
              '加载更多',
              onTap: controller.loadMore,
              width: 220.w,
              height: 70.h,
            ),
            SizedBox(width: 16.w),
            ButtonWidget.destructive(
              '清除当天',
              onTap: controller.clearCurrentDay,
              width: 220.w,
              height: 70.h,
            ),
          ].toRow(mainAxisAlignment: MainAxisAlignment.center);
        }

        return <Widget>[
          TextWidget.label(
            '已选 ${controller.selectedIndexes.length} 行',
            fontSize: 24.sp,
          ),
          SizedBox(width: 16.w),
          ButtonWidget.primary(
            '复制',
            onTap: controller.copySelected,
            width: 180.w,
            height: 70.h,
          ),
          SizedBox(width: 16.w),
          ButtonWidget.secondary(
            '导出',
            onTap: controller.exportSelected,
            width: 180.w,
            height: 70.h,
          ),
          SizedBox(width: 16.w),
          ButtonWidget.secondary(
            '取消',
            onTap: controller.exitSelectionMode,
            width: 180.w,
            height: 70.h,
          ),
        ].toRow(mainAxisAlignment: MainAxisAlignment.center);
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
    return <Widget>[
      SizedBox(height: 22.h),
      _buildDayTabs(),
      SizedBox(height: 14.h),
      _buildFilters(),
      SizedBox(height: 18.h),
      _buildActions(),
      SizedBox(height: 18.h),
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
