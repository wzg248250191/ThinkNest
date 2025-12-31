part of 'controller.dart';

/// 一体化页面“设备配置”能力集合
///
/// 说明：
/// - 负责 `deviceConfigs` 的读取/写入与本地持久化
/// - 当设备配置变更或加载完成后，会触发 `syncEnabledFromDeviceConfigs()` 同步开关可用性
mixin _IntegrationDeviceConfigMixin on GetxController {
  /// 当前所有设备配置（key 为标题，例如：'墙面主机'、'桌面投影'）
  Map<String, DeviceInfoConfig> get deviceConfigs;

  /// 同步一体化页面各开关的 `enabled` 状态
  ///
  /// 说明：
  /// - 这是抽象方法（接口约束），由其他 mixin 或宿主类提供实现
  /// - 当前实现位于 `_IntegrationSwitchMixin.syncEnabledFromDeviceConfigs`
  void syncEnabledFromDeviceConfigs();

  /// 按标题获取设备配置（未配置时返回默认值）
  DeviceInfoConfig getDeviceConfig(String title) {
    return deviceConfigs[title] ?? const DeviceInfoConfig();
  }

  /// 编辑设备信息时，更新“设备配置”并刷新页面
  ///
  /// 说明：
  /// - 会持久化到本地存储
  /// - 会同步各开关的 enabled，并刷新配置页 UI
  Future<void> setDeviceConfig(String title, DeviceInfoConfig config) async {
    deviceConfigs[title] = config;
    await _persistDeviceConfigs();
    syncEnabledFromDeviceConfigs();
    update(<String>["device_config"]);
  }

  /// 读取本地“设备配置”
  ///
  /// 说明：
  /// - 若本地无数据，会按默认标题集合生成默认配置
  /// - 读取完成后会同步 enabled，并刷新配置页 UI
  Future<void> loadDeviceConfigs() async {
    final String raw = Storage().getString(IntegrationController._deviceConfigsKey);
    if (raw.isEmpty) {
      deviceConfigs
        ..clear()
        ..addEntries(
          IntegrationController.deviceTitles
              .map((t) => MapEntry<String, DeviceInfoConfig>(t, const DeviceInfoConfig())),
        );
      syncEnabledFromDeviceConfigs();
      update(<String>["device_config"]);
      return;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        deviceConfigs.clear();
        for (final entry in map.entries) {
          final dynamic value = entry.value;
          if (value is Map) {
            deviceConfigs[entry.key] = DeviceInfoConfig.fromJson(value.cast<String, dynamic>());
          }
        }
      }
    } catch (_) {
      deviceConfigs.clear();
    }

    for (final title in IntegrationController.deviceTitles) {
      deviceConfigs.putIfAbsent(title, () => const DeviceInfoConfig());
    }

    syncEnabledFromDeviceConfigs();
    update(<String>["device_config"]);
  }

  /// 将当前 `deviceConfigs` 序列化并写入本地存储（用于应用下次启动恢复配置）。
  Future<void> _persistDeviceConfigs() async {
    final Map<String, dynamic> json = deviceConfigs.map(
      (k, v) => MapEntry<String, dynamic>(k, v.toJson()),
    );
    await Storage().setJson(IntegrationController._deviceConfigsKey, json);
  }
}
