/// 圆形开关组件的状态数据模型
///
/// 说明：
/// - [enabled] 表示当前开关是否可交互（禁用时通常置灰且不响应点击）
/// - [blocked] 表示当前开关是否被业务流程临时锁定（例如总开关编排等待期）
/// - [isOn] 表示当前开关的开/关状态（用于渲染与业务判断）
class SwitchCircleState {
  /// 当前开关是否可交互
  final bool enabled;

  /// 当前开关是否处于“被业务锁定，禁止点击”状态
  final bool blocked;

  /// 当前开关是否为“开启”状态
  final bool isOn;

  /// 创建一个不可变的开关状态
  const SwitchCircleState({
    required this.enabled,
    required this.isOn,
    this.blocked = false,
  });

  /// 基于当前对象生成一个新对象（不可变更新）
  ///
  /// 说明：
  /// - 未传入的字段会沿用当前对象的值
  SwitchCircleState copyWith({bool? enabled, bool? isOn, bool? blocked}) {
    return SwitchCircleState(
      enabled: enabled ?? this.enabled,
      isOn: isOn ?? this.isOn,
      blocked: blocked ?? this.blocked,
    );
  }
}
