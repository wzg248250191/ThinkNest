import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'models/device_info_config.dart';
import 'models/switch_circle_state.dart';
import 'integration_command_repository.dart';
import 'udp_hardware_command.dart';

class IntegrationController extends GetxController {
  IntegrationController();

  static const String _deviceConfigsKey = 'integration_device_configs_v1';

  static const List<String> deviceTitles = <String>[
    '总开关',
    '墙面主机',
    '墙面投影',
    '桌面主机',
    '桌面投影',
    '灯光',
    '窗帘',
  ];

  final Map<String, DeviceInfoConfig> deviceConfigs = <String, DeviceInfoConfig>{};
  final IntegrationCommandRepository commandRepository = IntegrationCommandRepository();

  //总开关
  SwitchCircleState mainState = const SwitchCircleState(enabled: true, isOn: true);
  //墙面开关
  SwitchCircleState wallState = const SwitchCircleState(enabled: true, isOn: false);
  //桌面开关
  SwitchCircleState deskState = const SwitchCircleState(enabled: true, isOn: false);
  //灯光开关
  SwitchCircleState lightState = const SwitchCircleState(enabled: false, isOn: false);
  //窗帘开关
  SwitchCircleState curtainState = const SwitchCircleState(enabled: false, isOn: false);

  // 内部 PageView 的控制器，用于右侧内容滑动切换
  final PageController innerPageController = PageController(initialPage: 0);
  bool isConfig = false;
  int _deviceConfigTapCount = 0;
  DateTime? _lastDeviceConfigTapAt;
  bool _mainBusy = false;
  bool _wallBusy = false;
  bool _deskBusy = false;
  bool _lightBusy = false;
  bool _curtainBusy = false;
  bool? _mainPendingDesired;
  bool? _wallPendingDesired;
  bool? _deskPendingDesired;
  bool? _lightPendingDesired;
  bool? _curtainPendingDesired;

  void setMainState(SwitchCircleState value) {
    unawaited(_toggleMain(value.isOn));
  }

  void setWallState(SwitchCircleState value) {
    unawaited(_toggleWall(value.isOn));
  }

  void setDeskState(SwitchCircleState value) {
    unawaited(_toggleDesk(value.isOn));
  }

  void setLightState(SwitchCircleState value) {
    unawaited(_toggleLight(value.isOn));
  }

  
  void setCurtainState(SwitchCircleState value) {
    unawaited(_toggleCurtain(value.isOn));
  }

  Future<UdpHardwareCommandResult> openMain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('总开关');
    return commandRepository.openDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> closeMain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('总开关');
    return commandRepository.closeDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> queryMain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('总开关');
    return commandRepository.queryDevice(cfg, timeout: timeout);
  }

  Future<List<UdpHardwareCommandResult>> openWall({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('墙面主机');
    final DeviceInfoConfig projector = getDeviceConfig('墙面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.openDevice(host, timeout: timeout),
      commandRepository.openDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<List<UdpHardwareCommandResult>> closeWall({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('墙面主机');
    final DeviceInfoConfig projector = getDeviceConfig('墙面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.closeDevice(host, timeout: timeout),
      commandRepository.closeDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<List<UdpHardwareCommandResult>> queryWall({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('墙面主机');
    final DeviceInfoConfig projector = getDeviceConfig('墙面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.queryDevice(host, timeout: timeout),
      commandRepository.queryDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<List<UdpHardwareCommandResult>> openDesk({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('桌面主机');
    final DeviceInfoConfig projector = getDeviceConfig('桌面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.openDevice(host, timeout: timeout),
      commandRepository.openDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<List<UdpHardwareCommandResult>> closeDesk({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('桌面主机');
    final DeviceInfoConfig projector = getDeviceConfig('桌面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.closeDevice(host, timeout: timeout),
      commandRepository.closeDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<List<UdpHardwareCommandResult>> queryDesk({Duration? timeout}) async {
    final DeviceInfoConfig host = getDeviceConfig('桌面主机');
    final DeviceInfoConfig projector = getDeviceConfig('桌面投影');
    final results = await Future.wait(<Future<UdpHardwareCommandResult>>[
      commandRepository.queryDevice(host, timeout: timeout),
      commandRepository.queryDevice(projector, timeout: timeout),
    ]);
    return results;
  }

  Future<UdpHardwareCommandResult> openLight({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('灯光');
    return commandRepository.openDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> closeLight({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('灯光');
    return commandRepository.closeDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> queryLight({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('灯光');
    return commandRepository.queryDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> openCurtain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('窗帘');
    return commandRepository.openDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> closeCurtain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('窗帘');
    return commandRepository.closeDevice(cfg, timeout: timeout);
  }

  Future<UdpHardwareCommandResult> queryCurtain({Duration? timeout}) async {
    final DeviceInfoConfig cfg = getDeviceConfig('窗帘');
    return commandRepository.queryDevice(cfg, timeout: timeout);
  }

  Future<void> refreshSwitchStatesFromHardware({Duration? timeout}) async {
    final List<Future<void>> tasks = <Future<void>>[];

    if (mainState.enabled) {
      tasks.add(_refreshMain(timeout: timeout));
    } else {
      mainState = mainState.copyWith(isOn: false);
    }

    if (wallState.enabled) {
      tasks.add(_refreshWall(timeout: timeout));
    } else {
      wallState = wallState.copyWith(isOn: false);
    }

    if (deskState.enabled) {
      tasks.add(_refreshDesk(timeout: timeout));
    } else {
      deskState = deskState.copyWith(isOn: false);
    }

    if (lightState.enabled) {
      tasks.add(_refreshLight(timeout: timeout));
    } else {
      lightState = lightState.copyWith(isOn: false);
    }

    if (curtainState.enabled) {
      tasks.add(_refreshCurtain(timeout: timeout));
    } else {
      curtainState = curtainState.copyWith(isOn: false);
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
    update(<String>["integration"]);
  }

  /// 根据本地“设备配置”的启用状态，刷新一体化页面各开关的 `enabled`（不改变 `isOn`）。
  void syncEnabledFromDeviceConfigs() {
    final bool mainEnabled = getDeviceConfig('总开关').enabled;
    final bool wallEnabled = getDeviceConfig('墙面主机').enabled && getDeviceConfig('墙面投影').enabled;
    final bool deskEnabled = getDeviceConfig('桌面主机').enabled && getDeviceConfig('桌面投影').enabled;
    final bool lightEnabled = getDeviceConfig('灯光').enabled;
    final bool curtainEnabled = getDeviceConfig('窗帘').enabled;

    mainState = mainState.copyWith(enabled: mainEnabled);
    wallState = wallState.copyWith(enabled: wallEnabled);
    deskState = deskState.copyWith(enabled: deskEnabled);
    lightState = lightState.copyWith(enabled: lightEnabled);
    curtainState = curtainState.copyWith(enabled: curtainEnabled);

    update(<String>["integration"]);
  }

  DeviceInfoConfig getDeviceConfig(String title) {
    return deviceConfigs[title] ?? const DeviceInfoConfig();
  }

///编辑设备信息时，更新“设备配置”并刷新页面
  Future<void> setDeviceConfig(String title, DeviceInfoConfig config) async {
    deviceConfigs[title] = config;
    await _persistDeviceConfigs();
    syncEnabledFromDeviceConfigs();
    update(<String>["device_config"]);
  }
///读取本地“设备配置”
  Future<void> loadDeviceConfigs() async {
    final String raw = Storage().getString(_deviceConfigsKey);
    if (raw.isEmpty) {
      deviceConfigs
        ..clear()
        ..addEntries(
          deviceTitles.map((t) => MapEntry<String, DeviceInfoConfig>(t, const DeviceInfoConfig())),
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

    for (final title in deviceTitles) {
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
    await Storage().setJson(_deviceConfigsKey, json);
  }

/// 处理“设备配置”项点击事件
  ///
  /// 说明：
  /// - 点击 5 次及以上，打开“设备配置”页
  void onDeviceConfigEntryTap() {
    if (isConfig) {
      return;
    }

    final now = DateTime.now();
    final last = _lastDeviceConfigTapAt;
    if (last == null || now.difference(last) > const Duration(milliseconds: 1200)) {
      _deviceConfigTapCount = 0;
    }

    _lastDeviceConfigTapAt = now;
    _deviceConfigTapCount += 1;

    if (_deviceConfigTapCount >= 5) {
      openConfig();
    }
  }

  void openConfig() {
    // 右→左滑入“关于我们”页
    innerPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = true;
    update(["integration"]);
  }

  void closeConfig() {
    // 左→右滑出返回设置列表
    innerPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = false;
    update(["integration"]);
  }

  void onInnerPageChanged(int index) {
    isConfig = index == 1;
    update(["integration"]);
  }

  _initData() {
    update(["integration"]);
  }

  void onTap() {}

  /// 总开关：点击后立即显示状态，并异步下发开/关指令
  Future<void> _toggleMain(bool desiredOn) async {
    // 若该开关未启用，则不处理点击
    if (!mainState.enabled) {
      // 直接返回，避免发指令与更新 UI
      return;
    }

    // 若当前 UI 状态与目标状态不同
    if (mainState.isOn != desiredOn) {
      // 立即更新 UI 状态（不等待硬件返回）
      mainState = mainState.copyWith(isOn: desiredOn);
      // 刷新一体化页面，让图标立刻变化
      update(<String>["integration"]);
    }

    // 若已有一次指令发送进行中
    if (_mainBusy) {
      // 记录用户最新想要的目标状态，待当前指令结束后再补发
      _mainPendingDesired = desiredOn;
      // 不并发发指令，避免 UDP 同时发送导致状态混乱
      return;
    }

    // 标记进入忙碌状态，防止并发发送
    _mainBusy = true;
    // 捕获发送过程异常，避免影响 UI 响应
    try {
      // 按目标状态发送开/关指令（不使用返回结果更新 UI）
      await (desiredOn ? openMain() : closeMain());
    }
    // 忽略异常（只在 debug 下输出），UI 仍保持用户选择
    catch (e) {
      // 仅在调试模式执行
      assert(() {
        // 输出异常信息便于排查
        debugPrint(e.toString());
        // assert 回调必须返回 true
        return true;
      }());
    }
    // 无论成功失败都要复位忙碌标记
    finally {
      // 标记指令发送结束
      _mainBusy = false;
    }

    // 读取期间用户可能再次点击的“最终目标状态”
    final bool? pending = _mainPendingDesired;
    // 清空待处理状态，避免重复补发
    _mainPendingDesired = null;
    // 若期间有新的目标状态且与本次不同
    if (pending != null && pending != desiredOn) {
      // 递归补发最后一次点击对应的指令（同样乐观更新）
      unawaited(_toggleMain(pending));
    }
  }

  Future<void> _toggleWall(bool desiredOn) async {
    if (!wallState.enabled) {
      return;
    }

    if (wallState.isOn != desiredOn) {
      wallState = wallState.copyWith(isOn: desiredOn);
      update(<String>["integration"]);
    }

    if (_wallBusy) {
      _wallPendingDesired = desiredOn;
      return;
    }

    _wallBusy = true;
    try {
      await (desiredOn ? openWall() : closeWall());
    } catch (e) {
      assert(() {
        debugPrint(e.toString());
        return true;
      }());
    } finally {
      _wallBusy = false;
    }

    final bool? pending = _wallPendingDesired;
    _wallPendingDesired = null;
    if (pending != null && pending != desiredOn) {
      unawaited(_toggleWall(pending));
    }
  }

  Future<void> _toggleDesk(bool desiredOn) async {
    if (!deskState.enabled) {
      return;
    }

    if (deskState.isOn != desiredOn) {
      deskState = deskState.copyWith(isOn: desiredOn);
      update(<String>["integration"]);
    }

    if (_deskBusy) {
      _deskPendingDesired = desiredOn;
      return;
    }

    _deskBusy = true;
    try {
      await (desiredOn ? openDesk() : closeDesk());
    } catch (e) {
      assert(() {
        debugPrint(e.toString());
        return true;
      }());
    } finally {
      _deskBusy = false;
    }

    final bool? pending = _deskPendingDesired;
    _deskPendingDesired = null;
    if (pending != null && pending != desiredOn) {
      unawaited(_toggleDesk(pending));
    }
  }

  Future<void> _toggleLight(bool desiredOn) async {
    if (!lightState.enabled) {
      return;
    }

    if (lightState.isOn != desiredOn) {
      lightState = lightState.copyWith(isOn: desiredOn);
      update(<String>["integration"]);
    }

    if (_lightBusy) {
      _lightPendingDesired = desiredOn;
      return;
    }

    _lightBusy = true;
    try {
      await (desiredOn ? openLight() : closeLight());
    } catch (e) {
      assert(() {
        debugPrint(e.toString());
        return true;
      }());
    } finally {
      _lightBusy = false;
    }

    final bool? pending = _lightPendingDesired;
    _lightPendingDesired = null;
    if (pending != null && pending != desiredOn) {
      unawaited(_toggleLight(pending));
    }
  }

  Future<void> _toggleCurtain(bool desiredOn) async {
    if (!curtainState.enabled) {
      return;
    }

    if (curtainState.isOn != desiredOn) {
      curtainState = curtainState.copyWith(isOn: desiredOn);
      update(<String>["integration"]);
    }

    if (_curtainBusy) {
      _curtainPendingDesired = desiredOn;
      return;
    }

    _curtainBusy = true;
    try {
      await (desiredOn ? openCurtain() : closeCurtain());
    } catch (e) {
      assert(() {
        debugPrint(e.toString());
        return true;
      }());
    } finally {
      _curtainBusy = false;
    }

    final bool? pending = _curtainPendingDesired;
    _curtainPendingDesired = null;
    if (pending != null && pending != desiredOn) {
      unawaited(_toggleCurtain(pending));
    }
  }

  Future<void> _refreshMain({Duration? timeout}) async {
    final UdpHardwareCommandResult result = await queryMain(timeout: timeout);
    final bool isOn =
        IntegrationCommandRepository.parseSwitchIsOn(result) ?? false;
    mainState = mainState.copyWith(isOn: isOn);
  }

  Future<void> _refreshWall({Duration? timeout}) async {
    final List<UdpHardwareCommandResult> results = await queryWall(timeout: timeout);
    final List<bool?> states =
        results.map(IntegrationCommandRepository.parseSwitchIsOn).toList();
    final bool isOn = states.isNotEmpty && states.every((e) => e == true);
    wallState = wallState.copyWith(isOn: isOn);
  }

  Future<void> _refreshDesk({Duration? timeout}) async {
    final List<UdpHardwareCommandResult> results = await queryDesk(timeout: timeout);
    final List<bool?> states =
        results.map(IntegrationCommandRepository.parseSwitchIsOn).toList();
    final bool isOn = states.isNotEmpty && states.every((e) => e == true);
    deskState = deskState.copyWith(isOn: isOn);
  }

  Future<void> _refreshLight({Duration? timeout}) async {
    final UdpHardwareCommandResult result = await queryLight(timeout: timeout);
    final bool isOn =
        IntegrationCommandRepository.parseSwitchIsOn(result) ?? false;
    lightState = lightState.copyWith(isOn: isOn);
  }

  Future<void> _refreshCurtain({Duration? timeout}) async {
    final UdpHardwareCommandResult result = await queryCurtain(timeout: timeout);
    final bool isOn =
        IntegrationCommandRepository.parseSwitchIsOn(result) ?? false;
    curtainState = curtainState.copyWith(isOn: isOn);
  }

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
