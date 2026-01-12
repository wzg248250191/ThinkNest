import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

enum AppLogType {
  print,
  error,
}

class AppLogLine {
  final DateTime timestamp;
  final AppLogType type;
  final String message;

  AppLogLine({
    required this.timestamp,
    required this.type,
    required this.message,
  });
}

class AppLogService extends GetxService {
  static final AppLogService instance = AppLogService._internal();

  factory AppLogService() => instance;

  AppLogService._internal();

  final List<String> _earlyBuffer = <String>[];
  final int keepDays = 3;

  Directory? _logDir;
  DateTime? _currentDay;
  IOSink? _sink;
  Future<void> _writeChain = Future<void>.value();
  bool _initialized = false;

  /// 初始化日志服务：创建目录、清理过期文件、并准备写入句柄
  Future<AppLogService> init() async {
    if (_initialized) return this;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logDir = Directory('${dir.path}${Platform.pathSeparator}logs');
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }
      await _purgeExpiredFiles();
      await _ensureSinkForDay(DateTime.now());
      await _flushEarlyBuffer();
    } catch (_) {
      _initialized = false;
    }
    return this;
  }

  /// 记录一条“打印日志”，用于承接 print/debugPrint 与业务日志
  void recordPrint(String message, {String? tag}) {
    _recordLines(
      type: AppLogType.print,
      message: message,
      tag: tag,
      stack: null,
    );
  }

  /// 记录一条“错误日志”，用于承接未捕获异常与框架错误
  void recordError(Object error, StackTrace stack, {String? tag}) {
    _recordLines(
      type: AppLogType.error,
      message: error.toString(),
      tag: tag,
      stack: stack,
    );
  }

  /// 静态兜底：在 GetX 服务尚未注册时也能记录打印日志
  static void tryRecordPrint(String message, {String? tag}) {
    instance.recordPrint(message, tag: tag);
  }

  /// 静态兜底：在 GetX 服务尚未注册时也能记录错误日志
  static void tryRecordError(Object error, StackTrace stack, {String? tag}) {
    instance.recordError(error, stack, tag: tag);
  }

  /// 读取指定日期的日志（默认只取尾部若干行，避免大文件一次性撑爆内存）
  Future<List<AppLogLine>> readDay(DateTime day, {int tailLines = 1500}) async {
    await init();
    final file = File(_dayFilePath(day));
    if (!await file.exists()) {
      return <AppLogLine>[];
    }
    final lines = await file.readAsLines();
    final start = lines.length > tailLines ? lines.length - tailLines : 0;
    // 关键逻辑：日志列表展示需要“最新在上”；文件按追加写入，尾部是最新，因此这里倒序返回。
    final sliced = lines.sublist(start).reversed;
    return sliced
        .map(_parseLine)
        .whereType<AppLogLine>()
        .toList(growable: false);
  }

  /// 清除指定日期的日志文件内容
  Future<void> clearDay(DateTime day) async {
    await init();
    await _writeChain;

    final targetDay = DateTime(day.year, day.month, day.day);
    final isCurrentDay = _currentDay == targetDay;
    if (isCurrentDay) {
      // 关键：清除当前正在写入的日志前，先关闭句柄，避免 Windows 下占用导致删除失败
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
      _currentDay = null;
    }

    final file = File(_dayFilePath(targetDay));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        try {
          await file.writeAsString('', flush: true);
        } catch (_) {}
      }
    }

    if (isCurrentDay) {
      await _ensureSinkForDay(DateTime.now());
    }
  }

  /// 导出指定日期的日志到一个新文件（用于分享/拷贝到电脑排查）
  Future<File?> exportDay(DateTime day) async {
    await init();
    final src = File(_dayFilePath(day));
    if (!await src.exists()) return null;
    final exportsDir = Directory('${_logDir!.path}${Platform.pathSeparator}exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final ts = DateTime.now();
    final fileName =
        'export_${ts.year}${_two(ts.month)}${_two(ts.day)}_${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}.log';
    final dest = File('${exportsDir.path}${Platform.pathSeparator}$fileName');
    return await src.copy(dest.path);
  }

  /// 导出选中的若干行日志到文件（便于在页面中多选后提取）
  Future<File?> exportSelectedLines(List<AppLogLine> lines) async {
    await init();
    final exportsDir = Directory('${_logDir!.path}${Platform.pathSeparator}exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final ts = DateTime.now();
    final fileName =
        'export_selected_${ts.year}${_two(ts.month)}${_two(ts.day)}_${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}.log';
    final dest = File('${exportsDir.path}${Platform.pathSeparator}$fileName');
    final content = lines.map(_formatLine).join('\n');
    await dest.writeAsString(content, flush: true);
    return dest;
  }

  /// 关闭写入资源（用于应用退出或测试场景）
  Future<void> disposeSink() async {
    await _writeChain;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  /// 将一条日志拆分为多行并按类型写入队列（错误会强制 flush）
  void _recordLines({
    required AppLogType type,
    required String message,
    required String? tag,
    required StackTrace? stack,
  }) {
    final now = DateTime.now();
    final prefix = _buildPrefix(now, type, tag: tag);
    final msgLines = message.split('\n');
    for (final l in msgLines) {
      _enqueueWrite('$prefix$l', flush: type == AppLogType.error);
    }

    if (stack != null) {
      final stackLines = stack.toString().split('\n');
      for (final l in stackLines) {
        if (l.trim().isEmpty) continue;
        _enqueueWrite('$prefix$l', flush: true);
      }
    }
  }

  /// 构造日志行前缀：时间戳 + 类型 + 可选 tag
  String _buildPrefix(DateTime time, AppLogType type, {required String? tag}) {
    final typeText = type == AppLogType.error ? 'ERROR' : 'PRINT';
    final tagText = (tag == null || tag.trim().isEmpty) ? '' : '[$tag] ';
    return '${time.toIso8601String()} [$typeText] $tagText';
  }

  /// 将结构化日志行格式化为“单行文本”，用于导出与复制
  String _formatLine(AppLogLine line) {
    final typeText = line.type == AppLogType.error ? 'ERROR' : 'PRINT';
    return '${line.timestamp.toIso8601String()} [$typeText] ${line.message}';
  }

  /// 将落盘的单行文本解析为结构化日志行
  AppLogLine? _parseLine(String raw) {
    final idx1 = raw.indexOf(' ');
    if (idx1 <= 0) return null;
    final tsStr = raw.substring(0, idx1);
    final rest = raw.substring(idx1 + 1);

    final match = RegExp(r'^\[(PRINT|ERROR)\]\s+(.*)$').firstMatch(rest);
    if (match == null) return null;
    final typeStr = match.group(1);
    final msg = match.group(2) ?? '';
    final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
    final type = typeStr == 'ERROR' ? AppLogType.error : AppLogType.print;
    return AppLogLine(timestamp: ts, type: type, message: msg);
  }

  /// 将日志写入串行队列，避免并发写文件导致内容交错
  void _enqueueWrite(String line, {required bool flush}) {
    if (!_initialized || _logDir == null) {
      _earlyBuffer.add(line);
      return;
    }

    _writeChain = _writeChain.then((_) async {
      await _ensureSinkForDay(DateTime.now());
      _sink?.writeln(line);
      if (flush) {
        await _sink?.flush();
      }
    });
  }

  /// 确保当天的写入句柄可用，跨天时自动切换新文件
  Future<void> _ensureSinkForDay(DateTime now) async {
    final day = DateTime(now.year, now.month, now.day);
    if (_sink != null && _currentDay == day) {
      return;
    }

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    _currentDay = day;
    final file = File(_dayFilePath(day));
    _sink = file.openWrite(mode: FileMode.append);
  }

  /// 生成指定日期的日志文件路径（按天分文件）
  String _dayFilePath(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final name = '${d.year}-${_two(d.month)}-${_two(d.day)}.log';
    return '${_logDir!.path}${Platform.pathSeparator}$name';
  }

  /// 清理过期日志文件，仅保留最近 keepDays 天
  Future<void> _purgeExpiredFiles() async {
    if (_logDir == null) return;
    final now = DateTime.now();
    final keep = <String>{};
    for (int i = 0; i < keepDays; i++) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      keep.add('${d.year}-${_two(d.month)}-${_two(d.day)}.log');
    }

    final entries = _logDir!.listSync(followLinks: false);
    for (final e in entries) {
      if (e is! File) continue;
      final base = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.last : '';
      if (base == 'exports') continue;
      if (!keep.contains(base)) {
        try {
          e.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 将初始化前缓存的日志写入到文件（用于兜底早期 print/错误）
  Future<void> _flushEarlyBuffer() async {
    if (_earlyBuffer.isEmpty) return;
    final buffered = List<String>.from(_earlyBuffer);
    _earlyBuffer.clear();
    for (final l in buffered) {
      _enqueueWrite(l, flush: false);
    }
    await _writeChain;
  }

  /// 将数字补齐为两位字符串（用于生成文件名）
  String _two(int v) => v < 10 ? '0$v' : '$v';
}
