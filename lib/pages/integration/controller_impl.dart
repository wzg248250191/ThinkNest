part of 'controller.dart';

/// 一体化页面 Controller 的最终组装实现
///
/// 说明：
/// - `controller_impl.dart` 中的 impl 表示 implementation（实现）
/// - 该文件负责把多个能力 mixin 组合成最终对外使用的 [IntegrationController]
class IntegrationController extends GetxController
    with _IntegrationDeviceConfigMixin, _IntegrationPageMixin, _IntegrationSwitchMixin {
  /// 创建 Controller 实例
  IntegrationController();

  /// 设备配置本地存储 key
  static const String _deviceConfigsKey = 'integration_device_configs_v1';

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

  /// 当前设备配置集合
  @override
  final Map<String, DeviceInfoConfig> deviceConfigs = <String, DeviceInfoConfig>{};

  /// UDP 指令仓库（open/close/query）
  @override
  final IntegrationCommandRepository commandRepository = IntegrationCommandRepository();

  /// 内部 PageView 的控制器，用于右侧内容滑动切换
  @override
  final PageController innerPageController = PageController(initialPage: 0);

  /// 当前是否处于“设备配置”页
  @override
  bool isConfig = false;

  /// 初始化：加载配置并从硬件刷新开关状态
  Future<void> _loadConfigsAndRefreshSwitchStates() async {
    await loadDeviceConfigs();
    await refreshSwitchStatesFromHardware();
  }

  @override
  /// 生命周期：初始化阶段加载配置与状态
  void onInit() {
    super.onInit();
    unawaited(_loadConfigsAndRefreshSwitchStates());
  }

  @override
  /// 生命周期：首帧完成后刷新入口页状态
  void onReady() {
    super.onReady();
    _initData();
  }

  @override
  /// 生命周期：释放 PageController
  void onClose() {
    innerPageController.dispose();
    super.onClose();
  }
}
