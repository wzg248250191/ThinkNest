part of '../controller.dart';

/// 一体化页面“开关状态”能力集合
///
/// 说明：
/// - 维护各逻辑开关的 UI 状态（enabled/isOn/blocked）
/// - 维护“忙碌态/待补发”用于防并发与补偿下发
/// - 负责开关状态本地持久化（仅当天有效）与恢复
/// - 负责把状态变更写回本地（防抖），并在销毁时清理定时器
mixin _IntegrationSwitchStateMixin on GetxController {
  /// 本地存储工具
  Storage get _storage => Storage();

  /// 标记当前是否处于“从本地恢复状态”的过程，避免恢复过程中触发重复写入
  bool _restoringSwitchStates = false;

  /// 状态写入本地的防抖计时器
  Timer? _persistSwitchStatesTimer;

  /// 逻辑开关状态容器（不可变对象：更新请用 copyWith 后整体替换）
  final Map<IntegrationSwitchType, SwitchCircleState> _switchStates =
      <IntegrationSwitchType, SwitchCircleState>{
    // 关键规则：总开关默认必须为关闭，避免“未操作也显示开启”的误导；是否开启由“当天有效”的恢复或硬件查询决定
    IntegrationSwitchType.main: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.wall: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.desk: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.light: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.curtain: const SwitchCircleState(enabled: true, isOn: false),
  };

  /// 单个开关当前是否正在下发指令（防止同一开关并发发送）
  final Map<IntegrationSwitchType, bool> _busy = <IntegrationSwitchType, bool>{
    for (final t in IntegrationSwitchType.values) t: false,
  };

  /// 当开关忙碌时，记录用户最后一次期望状态（待忙碌结束后补发）
  final Map<IntegrationSwitchType, bool?> _pendingDesired = <IntegrationSwitchType, bool?>{};

  /// 获取指定类型的开关状态（供 UI 读取）
  SwitchCircleState switchState(IntegrationSwitchType type) {
    return _switchStates[type] ?? const SwitchCircleState(enabled: false, isOn: false);
  }

  /// 获取内部保存的状态（保证非空）
  SwitchCircleState _mustSwitchState(IntegrationSwitchType type) {
    return _switchStates[type] ?? const SwitchCircleState(enabled: false, isOn: false);
  }

  /// 更新内部保存的状态（不可变更新：替换为新对象）
  ///
  /// 说明：
  /// - 变更总开关时，会触发 [_onMainSwitchTurnedOn]/[_onMainSwitchTurnedOff] 钩子
  /// - 非恢复流程下，会触发“防抖持久化”
  void _setSwitchState(IntegrationSwitchType type, SwitchCircleState next) {
    final SwitchCircleState? prev = _switchStates[type];
    if (type == IntegrationSwitchType.main) {
      final bool prevOn = prev?.isOn ?? false;
      if (!prevOn && next.isOn) {
        _onMainSwitchTurnedOn();
      }
      if (prevOn && !next.isOn) {
        _onMainSwitchTurnedOff();
      }
    }
    _switchStates[type] = next;
    if (!_restoringSwitchStates) {
      _schedulePersistSwitchStates();
    }
  }

  /// 总开关从关->开时的钩子（由其他能力 mixin 覆写）
  void _onMainSwitchTurnedOn() {}

  /// 总开关从开->关时的钩子（由其他能力 mixin 覆写）
  void _onMainSwitchTurnedOff() {}

  /// 判断两个时间是否为同一天（按本地时区）
  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 将动态值安全解析为 int（容错历史数据/异常格式）
  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 从本地存储恢复开关状态（仅当天有效）
  ///
  /// 规则：
  /// - 若本地无数据：直接返回
  /// - 若数据不合法/非当天：清除本地数据并返回
  /// - 若数据合法：恢复到内存，并触发一次 UI 刷新
  void _restoreSwitchStatesIfValidToday() {
    try {
      final dynamic decoded = _storage.getJson(IntegrationController._switchStatesKey);
      if (decoded == null) return;
      if (decoded is! Map) {
        // 防御：存储内容不是 Map 结构时按脏数据处理，避免后续解析逻辑异常
        _storage.remove(IntegrationController._switchStatesKey);
        return;
      }
      final Map<String, dynamic> map = decoded.cast<String, dynamic>();
      final int savedAtMs = _parseInt(map['savedAtMs']);
      if (savedAtMs <= 0) {
        _storage.remove(IntegrationController._switchStatesKey);
        return;
      }
      final DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      final DateTime now = DateTime.now();
      if (!_isSameLocalDay(savedAt, now)) {
        _storage.remove(IntegrationController._switchStatesKey);
        return;
      }

      final dynamic statesRaw = map['states'];
      if (statesRaw is! Map) {
        _storage.remove(IntegrationController._switchStatesKey);
        return;
      }
      final Map<String, dynamic> states = statesRaw.cast<String, dynamic>();

      _restoringSwitchStates = true;
      for (final type in IntegrationSwitchType.values) {
        final dynamic v = states[type.name];
        if (v is bool) {
          final SwitchCircleState cur = _mustSwitchState(type);
          _setSwitchState(type, cur.copyWith(isOn: v));
        }
      }
      _restoringSwitchStates = false;
      _schedulePersistSwitchStates();

      update(kIntegrationUpdateIds);
    } catch (_) {
      _storage.remove(IntegrationController._switchStatesKey);
    }
  }

  /// 将当前开关状态写入本地存储（用于下次启动回显）
  Future<void> _persistSwitchStates() async {
    final Map<String, bool> states = <String, bool>{
      for (final type in IntegrationSwitchType.values) type.name: _mustSwitchState(type).isOn,
    };
    final Map<String, dynamic> payload = <String, dynamic>{
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'states': states,
    };
    await _storage.setJson(IntegrationController._switchStatesKey, payload);
  }

  /// 触发一次“防抖持久化”，避免频繁写入存储
  void _schedulePersistSwitchStates() {
    _persistSwitchStatesTimer?.cancel();
    _persistSwitchStatesTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistSwitchStates());
    });
  }

  @override
  /// 生命周期：启动时尝试恢复当天开关状态
  void onInit() {
    super.onInit();
    _restoreSwitchStatesIfValidToday();
  }

  @override
  /// 生命周期：释放定时器
  void onClose() {
    _persistSwitchStatesTimer?.cancel();
    _persistSwitchStatesTimer = null;
    super.onClose();
  }
}
