part of '../controller.dart';

class IntegrationController extends GetxController
    with
        _IntegrationDeviceConfigMixin,
        _IntegrationPageMixin,
        _IntegrationSwitchStateMixin,
        _IntegrationSwitchCooldownMixin,
        _IntegrationSwitchActionsMixin {
  IntegrationController();

  static const String _deviceConfigsKey = 'integration_device_configs_v1';

  static const String _switchStatesKey = 'integration_switch_states_v1';

  /// 设备配置标题列表（用于初始化与展示）
  static const List<String> deviceTitles = <String>[
    '总开关',
    '墙面主机',
    '墙面投影',
    '桌面主机',
    '桌面投影',
    '灯光',
    '窗帘',
  ];

  @override
  final Map<String, DeviceInfoConfig> deviceConfigs = <String, DeviceInfoConfig>{};

  @override
  final IntegrationCommandRepository commandRepository = IntegrationCommandRepository();

  @override
  final PageController innerPageController = PageController(initialPage: 0);

  @override
  bool isConfig = false;

  Future<void> _loadConfigsAndRefreshSwitchStates() async {
    await loadDeviceConfigs();
    await refreshSwitchStatesFromHardware();
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadConfigsAndRefreshSwitchStates());
  }

  @override
  void onReady() {
    super.onReady();
    _initData();
  }

  @override
  void onClose() {
    innerPageController.dispose();
    super.onClose();
  }
}

