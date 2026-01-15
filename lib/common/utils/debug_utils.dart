import 'dart:developer' as developer;
import 'package:think_nest/common/services/log/app_log_service.dart';
import 'package:think_nest/common/utils/storage.dart';
import 'package:think_nest/common/values/constants.dart';

class DebugUtils {
  DebugUtils._();

  static bool _socketLogEnabled = true;

  /// 当前是否允许输出 Socket 重要日志
  static bool get socketLogEnabled => _socketLogEnabled;

  /// 初始化 Socket 日志开关（从本地存储读取）
  static Future<void> initSocketLogSwitch() async {
    final Storage storage = Storage();
    if (storage.containsKey(StorageKeys.socketLogEnabled)) {
      _socketLogEnabled = storage.getBool(StorageKeys.socketLogEnabled);
      return;
    }
    // 关键逻辑：首次安装/首次启动时默认开启 Socket 日志，避免连接/重连问题无日志可查。
    _socketLogEnabled = true;
    await storage.setBool(StorageKeys.socketLogEnabled, true);
  }

  /// 设置 Socket 日志开关（默认会写入本地存储）
  static Future<void> setSocketLogEnabled(bool enabled, {bool persist = true}) async {
    _socketLogEnabled = enabled;
    if (!persist) {
      return;
    }
    final Storage storage = Storage();
    await storage.setBool(StorageKeys.socketLogEnabled, enabled);
  }

  /// 仅在 Debug 下记录日志，避免 Release 额外开销。
  ///
  /// 说明：
  /// - 使用 assert 包裹，Release 下会被剔除
  /// - [name] 用于在日志面板中分类筛选
  static void log(String message, {String name = 'app'}) {
    // 关键逻辑：Socket 日志可开关；关闭时即使“错误/异常”也不输出，避免刷屏。
    if (name == 'socket' && !_socketLogEnabled) {
      return;
    }
    // 关键：将 DebugUtils 统一纳入“打印日志”落盘，便于回溯线上/现场问题
    AppLogService.tryRecordPrint(message, tag: name);
    assert(() {
      developer.log(message, name: name);
      return true;
    }());
  }
}
