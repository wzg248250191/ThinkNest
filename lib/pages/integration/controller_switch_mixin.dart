part of 'controller.dart';

/// 一体化页面“开关业务”能力集合
///
/// 说明：
/// - 维护 UI 层展示的开关状态（enabled/isOn）
/// - 将一个逻辑开关映射到一个或多个真实设备配置，并下发 UDP 开/关/查询指令
/// - 处理乐观更新、忙碌态、防抖补发、以及墙面/桌面开机后的服务器连接等待与重试
mixin _IntegrationSwitchMixin on GetxController {
  /// 命令仓库（负责把配置转为 UDP 指令并发送）
  IntegrationCommandRepository get commandRepository;

  /// 获取指定标题的设备配置（由设备配置 mixin 或宿主类提供）
  DeviceInfoConfig getDeviceConfig(String title);

  /// 一体化页面各开关状态（不可变对象，更新通过 copyWith 生成新对象）
  final Map<IntegrationSwitchType, SwitchCircleState> _switchStates =
      <IntegrationSwitchType, SwitchCircleState>{
    IntegrationSwitchType.main: const SwitchCircleState(enabled: true, isOn: true),
    IntegrationSwitchType.wall: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.desk: const SwitchCircleState(enabled: true, isOn: false),
    IntegrationSwitchType.light: const SwitchCircleState(enabled: false, isOn: false),
    IntegrationSwitchType.curtain: const SwitchCircleState(enabled: false, isOn: false),
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

  /// UI 回调：当某个开关状态改变时触发
  void onSwitchStateChanged(IntegrationSwitchType type, SwitchCircleState value) {
    unawaited(requestSwitchChange(type, value.isOn));
  }

  /// 对外统一入口：请求切换某个开关到期望状态，并在内部做规则编排
  ///
  /// 规则：
  /// - 开启非总开关：若总开关未开 → 先开总开关 → 等 10 秒 → 再开目标开关
  /// - 关闭总开关：先关所有子开关（可并行）→ 全部完成后 → 再关总开关
  /// - 编排执行期会临时锁定相关开关（blocked=true），避免用户重复点击打断流程
  Future<void> requestSwitchChange(IntegrationSwitchType type, bool desiredOn) async {
    final SwitchCircleState current = _mustSwitchState(type);
    if (!current.enabled || current.blocked) {
      return;
    }

    if (type == IntegrationSwitchType.main && !desiredOn) {
      final List<IntegrationSwitchType> allTypes = IntegrationSwitchType.values.toList();
      _setBlocked(allTypes, true);
      _optimisticallySetIsOn(IntegrationSwitchType.main, false);
      update(<String>["integration"]);
      try {
        final List<IntegrationSwitchType> subTypes =
            allTypes.where((t) => t != IntegrationSwitchType.main).toList();
        await Future.wait(<Future<void>>[
          for (final t in subTypes) _toggleSwitch(t, false),
        ]);
        await _toggleSwitch(IntegrationSwitchType.main, false);
      } finally {
        _setBlocked(allTypes, false);
      }
      return;
    }

    if (type != IntegrationSwitchType.main && desiredOn) {
      final SwitchCircleState mainState = _mustSwitchState(IntegrationSwitchType.main);
      if (!mainState.enabled) {
        _optimisticallySetIsOn(type, false);
        update(<String>["integration"]);
        return;
      }

      if (!mainState.isOn) {
        final List<IntegrationSwitchType> locked = <IntegrationSwitchType>[
          IntegrationSwitchType.main,
          type,
        ];
        _setBlocked(locked, true);
        _optimisticallySetIsOn(IntegrationSwitchType.main, true);
        _optimisticallySetIsOn(type, true);
        update(<String>["integration"]);
        try {
          await _toggleSwitch(IntegrationSwitchType.main, true);
          await Future.delayed(const Duration(seconds: 10));
          if (!_mustSwitchState(IntegrationSwitchType.main).isOn) {
            _optimisticallySetIsOn(type, false);
            update(<String>["integration"]);
            return;
          }
          await _toggleSwitch(type, true);
        } finally {
          _setBlocked(locked, false);
        }
        return;
      }
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

  /// 批量设置 blocked（用于编排执行期禁用点击）
  void _setBlocked(Iterable<IntegrationSwitchType> types, bool blocked) {
    bool changed = false;
    for (final t in types) {
      final SwitchCircleState cur = _mustSwitchState(t);
      if (cur.blocked == blocked) {
        continue;
      }
      _setSwitchState(t, cur.copyWith(blocked: blocked));
      changed = true;
    }
    if (changed) {
      update(<String>["integration"]);
    }
  }

  /// 获取内部保存的状态（保证非空）
  SwitchCircleState _mustSwitchState(IntegrationSwitchType type) {
    return _switchStates[type] ?? const SwitchCircleState(enabled: false, isOn: false);
  }

  /// 更新内部保存的状态（不可变更新：替换为新对象）
  void _setSwitchState(IntegrationSwitchType type, SwitchCircleState next) {
    _switchStates[type] = next;
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
    final List<DeviceInfoConfig> configs = _deviceConfigsOfSwitch(switchType);
    final List<Future<UdpHardwareCommandResult>> tasks = <Future<UdpHardwareCommandResult>>[
      for (final cfg in configs) _executeSingleDevice(cfg, commandType, timeout: timeout),
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
        tasks.add(_refreshSwitch(type, timeout: timeout));
      } else {
        _setSwitchState(type, current.copyWith(isOn: false));
      }
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
    update(<String>["integration"]);
  }

  /// 根据本地“设备配置”的启用状态，刷新一体化页面各开关的 `enabled`（不改变 `isOn`）。
  void syncEnabledFromDeviceConfigs() {
    for (final type in IntegrationSwitchType.values) {
      final bool enabled = type.deviceConfigTitles.every((t) => getDeviceConfig(t).enabled);
      final SwitchCircleState current = _mustSwitchState(type);
      _setSwitchState(type, current.copyWith(enabled: enabled));
    }

    update(<String>["integration"]);
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
      update(<String>["integration"]);
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
    final List<UdpHardwareCommandResult> results = await executeSwitchCommand(
      type,
      commandType: IntegrationDeviceCommandType.query,
      timeout: timeout,
    );
    final List<bool?> states = results.map(IntegrationCommandRepository.parseSwitchIsOn).toList();
    final bool isOn = states.isNotEmpty && states.every((e) => e == true);
    final SwitchCircleState current = _mustSwitchState(type);
    _setSwitchState(type, current.copyWith(isOn: isOn));
  }
}
