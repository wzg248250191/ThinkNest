import 'dart:developer' as developer;

class DebugUtils {
  DebugUtils._();

  /// 仅在 Debug 下记录日志，避免 Release 额外开销。
  ///
  /// 说明：
  /// - 使用 assert 包裹，Release 下会被剔除
  /// - [name] 用于在日志面板中分类筛选
  static void log(String message, {String name = 'app'}) {
    assert(() {
      developer.log(message, name: name);
      return true;
    }());
  }
}

