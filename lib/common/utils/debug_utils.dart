import 'dart:developer' as developer;
import 'package:think_nest/common/services/log/app_log_service.dart';

class DebugUtils {
  DebugUtils._();

  /// 仅在 Debug 下记录日志，避免 Release 额外开销。
  ///
  /// 说明：
  /// - 使用 assert 包裹，Release 下会被剔除
  /// - [name] 用于在日志面板中分类筛选
  static void log(String message, {String name = 'app'}) {
    // 关键：将 DebugUtils 统一纳入“打印日志”落盘，便于回溯线上/现场问题
    AppLogService.tryRecordPrint(message, tag: name);
    assert(() {
      developer.log(message, name: name);
      return true;
    }());
  }
}

