part of '../controller.dart';

/// 一体化页面“开关业务编排与硬件交互”能力集合
///
/// 说明：
/// - 处理 UI 层开关点击回调与业务规则（主开关约束/关闭确认/冷却期限制等）
/// - 将逻辑开关映射到设备配置集合并下发 UDP 指令（开/关/查询）
/// - 处理并发与补发（同一开关忙碌时记录最后一次期望）
/// - 对墙面/桌面开机后等待 PC 服务端启动并尝试连接
mixin _IntegrationSwitchActionsMixin on GetxController, _IntegrationSwitchStateMixin, _IntegrationSwitchCooldownMixin {
  /// 指令仓库（负责把配置转为 UDP 指令并发送）
  IntegrationCommandRepository get commandRepository;

  /// 按标题获取设备配置（由设备配置 mixin 或宿主类提供）
  DeviceInfoConfig getDeviceConfig(String title);

  /// UI 回调：当某个开关状态改变时触发
  void onSwitchStateChanged(IntegrationSwitchType type, SwitchCircleState value) {
    unawaited(requestSwitchChange(type, value.isOn));
  }

  /// 对外统一入口：请求切换某个开关到期望状态，并在内部做规则编排
  ///
  /// 规则：
  /// - 开启墙面/桌面/灯光/窗帘：仅当总开关已开启时才允许开启，否则提示“请先开启总开关”
  /// - 关闭总开关：仅当墙面/桌面/灯光/窗帘均已关闭时才允许关闭，否则提示“请先关闭...”
  /// - 冷却期限制：总开关开启后的一段时间内，不允许操作子开关，弹窗提示剩余时间
  Future<void> requestSwitchChange(IntegrationSwitchType type, bool desiredOn) async {
    final SwitchCircleState current = _mustSwitchState(type);
    if (!current.enabled || current.blocked) {
      return;
    }

    if (type != IntegrationSwitchType.main) {
      final int remaining = _remainingMainCooldownSeconds();
      if (remaining > 0) {
        if (desiredOn != current.isOn) {
          _optimisticallySetIsOn(type, current.isOn);
          update(kIntegrationUpdateIds);
        }
        unawaited(_showMainCooldownDialog());
        return;
      }
    }

    if (type != IntegrationSwitchType.main && desiredOn) {
      final SwitchCircleState mainState = _mustSwitchState(IntegrationSwitchType.main);
      if (!mainState.isOn) {
        _optimisticallySetIsOn(type, false);
        update(kIntegrationUpdateIds);
        ToastUtils.show('请先开启总开关');
        return;
      }
    }

    if (type == IntegrationSwitchType.main && !desiredOn) {
      final List<IntegrationSwitchType> openedSubs = IntegrationSwitchType.values
          .where((t) => t != IntegrationSwitchType.main && _mustSwitchState(t).isOn)
          .toList();
      if (openedSubs.isNotEmpty) {
        update(kIntegrationUpdateIds);
        ToastUtils.show('请先关闭${openedSubs.map((e) => e.displayName).join('、')}');
        return;
      }

      _optimisticallySetIsOn(type, true);
      update(kIntegrationUpdateIds);

      await Get.dialog<void>(
        ConfirmDialog(
          message: '请检查所有设备是否已经关闭，\n如有设备未关闭强制断电可能会对设备造成一定的损坏，\n请谨慎使用',
          leftText: '取消',
          rightText: '确定',
          height: 320.h,
          onRightTap: () async {
            await _toggleSwitch(type, false);
          },
        ),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.5),
      );
      return;
    }

    await _toggleSwitch(type, desiredOn);
  }

  /// 仅修改本地状态的 isOn（用于“等待期/编排期”的 UI 乐观展示）
  void _optimisticallySetIsOn(IntegrationSwitchType type, bool desiredOn) {
    final SwitchCircleState cur = _mustSwitchState(type);
    if (cur.isOn == desiredOn) {
      return;
    }
    _setSwitchState(type, cur.copyWith(isOn: desiredOn));
  }

  /// 执行一次开关对应的设备命令（打开/关闭/查询）
  ///
  /// 返回：
  /// - 统一返回 List，便于处理“墙面/桌面”这类多设备组合开关
  Future<List<UdpHardwareCommandResult>> executeSwitchCommand(
    IntegrationSwitchType switchType, {
    required IntegrationDeviceCommandType commandType,
    Duration? timeout,
  }) async {
    final List<MapEntry<String, DeviceInfoConfig>> entries = _deviceConfigEntriesOfSwitch(switchType);
    final List<UdpHardwareCommandResult?> results =
        List<UdpHardwareCommandResult?>.filled(entries.length, null);

    final bool isWallOrDesk = switchType == IntegrationSwitchType.wall || switchType == IntegrationSwitchType.desk;
    final bool isOpenOrClose =
        commandType == IntegrationDeviceCommandType.open || commandType == IntegrationDeviceCommandType.close;

    if (isWallOrDesk && isOpenOrClose) {
      final List<int> hostIndexes = <int>[];
      final List<int> nonHostIndexes = <int>[];
      for (int i = 0; i < entries.length; i++) {
        final String title = entries[i].key;
        if (title.contains('主机')) {
          hostIndexes.add(i);
        } else {
          nonHostIndexes.add(i);
        }
      }

      Future<void> runIndexes(List<int> indexes) async {
        if (indexes.isEmpty) {
          return;
        }
        await Future.wait(<Future<void>>[
          for (final i in indexes)
            () async {
              results[i] = await _executeSingleDevice(entries[i].value, commandType, timeout: timeout);
            }(),
        ]);
      }

      final Duration delay = const Duration(seconds: 10);
      if (commandType == IntegrationDeviceCommandType.open) {
        await runIndexes(nonHostIndexes);
        if (nonHostIndexes.isNotEmpty && hostIndexes.isNotEmpty) {
          await Future.delayed(delay);
        }
        await runIndexes(hostIndexes);
      } else {
        await runIndexes(hostIndexes);
        if (nonHostIndexes.isNotEmpty && hostIndexes.isNotEmpty) {
          await Future.delayed(delay);
        }
        await runIndexes(nonHostIndexes);
      }

      return results.whereType<UdpHardwareCommandResult>().toList();
    }

    final List<Future<UdpHardwareCommandResult>> tasks = <Future<UdpHardwareCommandResult>>[
      for (final e in entries) _executeSingleDevice(e.value, commandType, timeout: timeout),
    ];
    return Future.wait(tasks);
  }

  /// 将一次命令下发到单个设备配置
  Future<UdpHardwareCommandResult> _executeSingleDevice(
    DeviceInfoConfig config,
    IntegrationDeviceCommandType type, {
    Duration? timeout,
  }) {
    switch (type) {
      case IntegrationDeviceCommandType.open:
        return commandRepository.openDevice(config, timeout: timeout);
      case IntegrationDeviceCommandType.close:
        return commandRepository.closeDevice(config, timeout: timeout);
      case IntegrationDeviceCommandType.query:
        return commandRepository.queryDevice(config, timeout: timeout);
    }
  }

  /// 获取某个逻辑开关关联的设备配置集合（按配置标题映射）
  List<DeviceInfoConfig> _deviceConfigsOfSwitch(IntegrationSwitchType type) {
    return <DeviceInfoConfig>[
      for (final title in type.deviceConfigTitles) getDeviceConfig(title),
    ];
  }

  List<MapEntry<String, DeviceInfoConfig>> _deviceConfigEntriesOfSwitch(IntegrationSwitchType type) {
    return <MapEntry<String, DeviceInfoConfig>>[
      for (final title in type.deviceConfigTitles) MapEntry<String, DeviceInfoConfig>(title, getDeviceConfig(title)),
    ];
  }

  bool _hasQueryCommandForSwitch(IntegrationSwitchType type) {
    final List<DeviceInfoConfig> configs = _deviceConfigsOfSwitch(type);
    if (configs.isEmpty) {
      return false;
    }
    return configs.every((cfg) => cfg.queryCmd.trim().isNotEmpty);
  }

  /// 从硬件查询各开关当前状态，并刷新到 UI
  ///
  /// 说明：
  /// - 仅对 enabled=true 的开关下发查询指令
  /// - 对 disabled 的开关，强制将 isOn 置为 false，避免 UI 显示“开着但不可用”
  Future<void> refreshSwitchStatesFromHardware({Duration? timeout}) async {
    final List<Future<void>> tasks = <Future<void>>[];

    for (final type in IntegrationSwitchType.values) {
      final SwitchCircleState current = _mustSwitchState(type);
      if (current.enabled) {
        if (_hasQueryCommandForSwitch(type)) {
          tasks.add(_refreshSwitch(type, timeout: timeout));
        }
      } else {
        _setSwitchState(type, current.copyWith(isOn: false));
      }
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
    update(kIntegrationUpdateIds);
  }

  /// 根据本地“设备配置”的启用状态，刷新一体化页面各开关的 `enabled`（不改变 `isOn`）。
  void syncEnabledFromDeviceConfigs() {
    for (final type in IntegrationSwitchType.values) {
      final bool enabled = type.deviceConfigTitles.every((t) => getDeviceConfig(t).enabled);
      final SwitchCircleState current = _mustSwitchState(type);
      _setSwitchState(type, current.copyWith(enabled: enabled));
    }

    update(kIntegrationUpdateIds);
  }

  /// 将“逻辑开关类型”映射到需要连接的 PC 服务器类型（仅墙面/桌面需要）
  ServerType? _serverTypeForSwitch(IntegrationSwitchType type) {
    switch (type) {
      case IntegrationSwitchType.wall:
        return ServerType.wall;
      case IntegrationSwitchType.desk:
        return ServerType.desktop;
      case IntegrationSwitchType.main:
      case IntegrationSwitchType.light:
      case IntegrationSwitchType.curtain:
        return null;
    }
  }

  /// 开启墙面/桌面后，等待 PC 服务端自启完成并尝试连接对应服务器
  ///
  /// 说明：
  /// - 使用 SocketService.ensureConnected：先判断已连接 → 再尝试历史 IP 直连 → 失败再 UDP 扫描兜底
  /// - 等待窗口需要偏长（主机开机与 PC 服务端自启动需要时间）
  /// - 若等待/重试期间用户把开关关闭，会停止继续尝试
  Future<void> _ensureServerConnectedForSwitch(IntegrationSwitchType type) async {
    final ServerType? serverType = _serverTypeForSwitch(type);
    if (serverType == null) {
      return;
    }
    if (!Get.isRegistered<SocketService>()) {
      return;
    }

    final SocketService socketService = Get.find<SocketService>();
    const Duration initialDelay = Duration(seconds: 10);
    const int maxAttempts = 15;
    const Duration retryDelay = Duration(seconds: 6);
    const Duration udpTimeout = Duration(seconds: 6);

    await Future.delayed(initialDelay);
    for (int i = 0; i < maxAttempts; i++) {
      if (!_mustSwitchState(type).isOn) {
        return;
      }

      final bool ok = await socketService.ensureConnected(
        serverType,
        udpTimeout: udpTimeout,
      );
      if (ok) {
        return;
      }

      if (i < maxAttempts - 1) {
        await Future.delayed(retryDelay);
      }
    }
  }

  /// 点击开关后立即乐观更新 UI，并异步下发开/关指令
  ///
  /// 说明：
  /// - 若指令尚在发送中，则只记录“最后一次用户期望”，待当前指令完成后补发
  Future<void> _toggleSwitch(IntegrationSwitchType type, bool desiredOn) async {
    final SwitchCircleState current = _mustSwitchState(type);
    if (!current.enabled) {
      return;
    }

    if (current.isOn != desiredOn) {
      _setSwitchState(type, current.copyWith(isOn: desiredOn));
      update(kIntegrationUpdateIds);
    }

    if (_busy[type] == true) {
      _pendingDesired[type] = desiredOn;
      return;
    }

    _busy[type] = true;
    bool commandOk = false;
    try {
      await executeSwitchCommand(
        type,
        commandType: desiredOn ? IntegrationDeviceCommandType.open : IntegrationDeviceCommandType.close,
      );
      commandOk = true;
    } catch (e) {
      assert(() {
        debugPrint(e.toString());
        return true;
      }());
    } finally {
      _busy[type] = false;
    }

    if (commandOk && desiredOn) {
      unawaited(_ensureServerConnectedForSwitch(type));
    }

    final bool? pending = _pendingDesired[type];
    _pendingDesired[type] = null;
    if (pending != null && pending != desiredOn) {
      unawaited(_toggleSwitch(type, pending));
    }
  }

  /// 从硬件查询单个开关状态，并刷新到本地状态
  ///
  /// 规则：
  /// - 只要该开关关联的任一设备无法解析为 true，则认为该开关为关闭
  Future<void> _refreshSwitch(IntegrationSwitchType type, {Duration? timeout}) async {
    if (!_hasQueryCommandForSwitch(type)) {
      return;
    }
    final List<UdpHardwareCommandResult> results = await executeSwitchCommand(
      type,
      commandType: IntegrationDeviceCommandType.query,
      timeout: timeout,
    );
    final List<bool?> states = results.map(IntegrationCommandRepository.parseSwitchIsOn).toList();
    if (states.isEmpty) {
      return;
    }
    if (states.any((e) => e == null)) {
      return;
    }
    final bool isOn = states.every((e) => e == true);
    final SwitchCircleState current = _mustSwitchState(type);
    _setSwitchState(type, current.copyWith(isOn: isOn));
  }
}
