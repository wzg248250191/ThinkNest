import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

enum LogsFilterType {
  all,
  error,
  print,
}

class LogsDisplayItem {
  final int sourceIndex;
  final AppLogLine line;

  LogsDisplayItem({
    required this.sourceIndex,
    required this.line,
  });
}

class LogsController extends GetxController {
  /// 当前查看的日期偏移（0=今天，1=昨天，2=前天）
  int dayOffset = 0;

  /// 当前加载的尾部行数上限（用于“加载更多”）
  int tailLines = 1500;

  /// 是否正在加载日志
  bool isLoading = false;

  /// 是否处于多选模式
  bool selectionMode = false;

  /// 多选模式下选中的行索引集合
  final Set<int> selectedIndexes = <int>{};

  /// 当前展示的日志行
  List<AppLogLine> lines = <AppLogLine>[];

  /// 日志筛选类型：0=全部，1=错误，2=打印
  int filterIndex = 0;

  /// 当前查看日期（只保留到天）
  DateTime get selectedDay {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: dayOffset));
    return day;
  }

  /// 当前查看日期的标题文案
  String get selectedDayLabel {
    if (dayOffset == 0) return '今天';
    if (dayOffset == 1) return '昨天';
    return '前天';
  }

  /// 当前筛选类型（用于列表展示）
  LogsFilterType get filterType {
    if (filterIndex == 1) return LogsFilterType.error;
    if (filterIndex == 2) return LogsFilterType.print;
    return LogsFilterType.all;
  }

  /// 根据筛选类型生成“展示列表”，并保留源索引用于多选/复制/导出
  List<LogsDisplayItem> get displayItems {
    final type = filterType;
    if (type == LogsFilterType.all) {
      return List<LogsDisplayItem>.generate(
        lines.length,
        (i) => LogsDisplayItem(sourceIndex: i, line: lines[i]),
        growable: false,
      );
    }
    final target = type == LogsFilterType.error ? AppLogType.error : AppLogType.print;
    final items = <LogsDisplayItem>[];
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.type != target) continue;
      items.add(LogsDisplayItem(sourceIndex: i, line: l));
    }
    return items;
  }

  @override
  /// 控制器初始化：默认加载今天日志
  void onInit() {
    super.onInit();
    loadLogs(resetTail: true);
  }

  /// 切换日期并刷新日志
  void selectDayOffset(int offset) {
    if (offset < 0 || offset > 2) return;
    if (dayOffset == offset) return;
    dayOffset = offset;
    exitSelectionMode();
    loadLogs(resetTail: true);
  }

  /// 切换日志筛选类型：全部/错误/打印
  void selectFilterIndex(int index) {
    if (index < 0 || index > 2) return;
    if (filterIndex == index) return;
    filterIndex = index;
    exitSelectionMode();
    update(['logs_filters', 'logs_actions', 'logs']);
  }

  /// 加载日志文件尾部若干行并刷新列表
  Future<void> loadLogs({required bool resetTail}) async {
    if (resetTail) {
      tailLines = 1500;
    }
    isLoading = true;
    update(['logs']);
    try {
      lines = await AppLogService.instance.readDay(selectedDay, tailLines: tailLines);
    } catch (e, s) {
      // 关键：读取文件失败也要记录，避免“看不到日志导致更难排查”
      AppLogService.tryRecordError(e, s, tag: 'logs_read');
      lines = <AppLogLine>[];
    } finally {
      isLoading = false;
      // 关键：日志重新加载后，剔除已失效的选中索引，避免越界
      selectedIndexes.removeWhere((i) => i < 0 || i >= lines.length);
      if (selectedIndexes.isEmpty) {
        selectionMode = false;
      }
      update(['logs']);
      update(['logs_actions']);
    }
  }

  /// 触发“加载更多”，扩大尾部读取范围
  void loadMore() {
    tailLines += 1500;
    loadLogs(resetTail: false);
  }

  /// 进入多选模式并默认选中当前行
  void enterSelectionMode(int index) {
    selectionMode = true;
    selectedIndexes.add(index);
    update(['logs_actions', 'logs']);
  }

  /// 退出多选模式并清空选中状态
  void exitSelectionMode() {
    selectionMode = false;
    selectedIndexes.clear();
    update(['logs_actions', 'logs']);
  }

  /// 切换某一行的选中状态
  void toggleSelected(int index) {
    if (!selectionMode) return;
    if (selectedIndexes.contains(index)) {
      selectedIndexes.remove(index);
    } else {
      selectedIndexes.add(index);
    }
    if (selectedIndexes.isEmpty) {
      selectionMode = false;
    }
    update(['logs_actions', 'logs']);
  }

  /// 复制选中的日志到剪贴板
  Future<void> copySelected() async {
    final selected = _selectedLines();
    if (selected.isEmpty) {
      ToastUtils.show('请先选择日志');
      return;
    }
    final content = selected.map(_formatLine).join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    ToastUtils.show('已复制 ${selected.length} 行');
  }

  /// 导出选中的日志到本地文件
  Future<void> exportSelected() async {
    final selected = _selectedLines();
    if (selected.isEmpty) {
      ToastUtils.show('请先选择日志');
      return;
    }
    final file = await AppLogService.instance.exportSelectedLines(selected);
    if (file == null) {
      ToastUtils.show('导出失败');
      return;
    }
    ToastUtils.show('已导出到：${file.path}');
  }

  /// 导出当天日志到本地文件
  Future<void> exportDay() async {
    final file = await AppLogService.instance.exportDay(selectedDay);
    if (file == null) {
      ToastUtils.show('当天无日志可导出');
      return;
    }
    ToastUtils.show('已导出到：${file.path}');
  }

  /// 清除当前选中日期的日志文件（仅影响该天，不影响其它日期与导出文件）
  Future<void> clearCurrentDay() async {
    final ok = await AlertDialog.show('确定清除$selectedDayLabel日志？');
    if (!ok) return;
    try {
      await AppLogService.instance.clearDay(selectedDay);
      exitSelectionMode();
      await loadLogs(resetTail: true);
      ToastUtils.show('已清除$selectedDayLabel日志');
    } catch (e, s) {
      // 关键：清除失败通常是文件占用/权限问题，需要记录错误便于现场排查
      AppLogService.tryRecordError(e, s, tag: 'logs_clear');
      ToastUtils.show('清除失败');
    }
  }

  /// 将选中索引映射为实际日志行列表（保持索引升序）
  List<AppLogLine> _selectedLines() {
    final indexes = selectedIndexes.toList()..sort();
    final selected = <AppLogLine>[];
    for (final i in indexes) {
      if (i < 0 || i >= lines.length) continue;
      selected.add(lines[i]);
    }
    return selected;
  }

  /// 将结构化日志行格式化为单行文本（用于复制与导出）
  String _formatLine(AppLogLine line) {
    final typeText = line.type == AppLogType.error ? 'ERROR' : 'PRINT';
    return '${line.timestamp.toIso8601String()} [$typeText] ${line.message}';
  }
}
