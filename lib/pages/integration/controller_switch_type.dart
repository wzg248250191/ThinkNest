part of 'controller.dart';

/// 一体化页面中的“逻辑开关”类型
///
/// 说明：
/// - 这是 UI 层看到的开关类型（总开关/墙面/桌面/灯光/窗帘）
/// - 每个开关对应一个或多个真实设备配置项（例如墙面=墙面主机+墙面投影）
enum IntegrationSwitchType {
  /// 总开关（通常只有一个设备配置项）
  main(
    displayName: '总开关',
    deviceConfigTitles: <String>['总开关'],
  ),
  /// 墙面开关（由墙面主机与墙面投影组合而成）
  wall(
    displayName: '墙面开关',
    deviceConfigTitles: <String>['墙面主机', '墙面投影'],
  ),
  /// 桌面开关（由桌面主机与桌面投影组合而成）
  desk(
    displayName: '桌面开关',
    deviceConfigTitles: <String>['桌面主机', '桌面投影'],
  ),
  /// 灯光开关
  light(
    displayName: '灯光开关',
    deviceConfigTitles: <String>['灯光'],
  ),
  /// 窗帘开关
  curtain(
    displayName: '窗帘开关',
    deviceConfigTitles: <String>['窗帘'],
  );

  /// 构造枚举值
  const IntegrationSwitchType({
    required this.displayName,
    required this.deviceConfigTitles,
  });

  /// UI 展示名称
  final String displayName;

  /// 该开关依赖的设备配置标题集合（用于 enabled 同步与批量下发命令）
  final List<String> deviceConfigTitles;
}
