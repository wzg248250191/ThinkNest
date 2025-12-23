import 'package:flutter_test/flutter_test.dart';
import 'package:think_nest/pages/integration/controller.dart';
import 'package:think_nest/pages/integration/models/device_info_config.dart';

void main() {
  test('syncEnabledFromDeviceConfigs computes enabled flags correctly', () {
    final IntegrationController controller = IntegrationController();

    controller.deviceConfigs
      ..clear()
      ..addAll(<String, DeviceInfoConfig>{
        '总开关': const DeviceInfoConfig(enabled: true),
        '墙面主机': const DeviceInfoConfig(enabled: true),
        '墙面投影': const DeviceInfoConfig(enabled: false),
        '桌面主机': const DeviceInfoConfig(enabled: true),
        '桌面投影': const DeviceInfoConfig(enabled: true),
        '灯光': const DeviceInfoConfig(enabled: false),
        '窗帘': const DeviceInfoConfig(enabled: true),
      });

    controller.syncEnabledFromDeviceConfigs();

    expect(controller.mainState.enabled, isTrue);
    expect(controller.wallState.enabled, isFalse);
    expect(controller.deskState.enabled, isTrue);
    expect(controller.lightState.enabled, isFalse);
    expect(controller.curtainState.enabled, isTrue);
  });
}

