/// SocketService 的“连接与发现”能力集合（同一 library 的 part 文件）。
///
/// 这个 mixin 负责把“网络层能力”接入到 [SocketServiceBase]：
/// - 生命周期：在 onInit 中初始化 SocketClientManager 与 UdpDiscoveryService，并注册回调
/// - UDP 扫描：scanForServers + 扫描复用（避免并发扫描）
/// - 连接管理：connect/disconnect、启动恢复连接、ensureConnected 兜底策略
/// - 端点持久化：缓存历史 IP/端口，减少扫描次数
/// - 回调分发：将 clientManager 的 state/message 回调写入 endpoint 流并交给 _handleMessage 处理
///
/// 说明：该文件是 part of socket_service.dart，不应被独立 import/export。
part of 'socket_service.dart';

class _EnsureConnectSession {
  _EnsureConnectSession({
    required this.id,
    required this.priority,
    required this.source,
    required this.autoReconnect,
    required this.connectTimeout,
    required this.udpTimeout,
    required this.udpFallback,
    required this.preferReconnect,
    required this.lastEndpointAttempts,
    required this.forceDisconnect,
  });

  final int id;
  final int priority;
  final String source;
  final bool autoReconnect;
  final Duration? connectTimeout;
  final Duration udpTimeout;
  final bool udpFallback;
  final bool preferReconnect;
  final int lastEndpointAttempts;
  final bool forceDisconnect;
  bool cancelled = false;
}

mixin SocketServiceConnectionMixin on SocketServiceBase, SocketServiceSendMixin {
  final Map<ServerType, _EnsureConnectSession> _ensureConnectSessions = <ServerType, _EnsureConnectSession>{};
  int _ensureConnectSessionSeq = 0;

  Timer? _foregroundHealthTimer;
  bool _isAppInForeground = true;
  int _lastAppPausedMs = 0;
  int _lastForegroundResumedMs = 0;
  int _lastResumeRecoverTriggeredMs = 0;

  static const Duration _foregroundHealthCheckInterval = Duration(seconds: 10);
  static const Duration _foregroundRxStaleThreshold = Duration(seconds: 45);
  static const Duration _resumeForceRecoverThreshold = Duration(seconds: 25);
  static const Duration _recoverThrottle = Duration(seconds: 10);
  static const Duration _foregroundHealthCheckActiveWindow = Duration(seconds: 120);
  static const Duration _resumeRecoverDebounce = Duration(seconds: 5);

  @override
  /// 返回“通过类型复核后的连接状态”，避免底层 Socket 刚连上时 UI 提前显示为成功
  bool isConnected(ServerType serverType) {
    return _endpoint(serverType).connectionState.value == SocketState.connected;
  }

  /// 初始化应用生命周期监听与前台连接健康检查
  void _initLifecycleAndHealthCheck() {
    WidgetsBinding.instance.addObserver(this);
    _startForegroundHealthCheckTimer();
  }

  /// 启动前台连接健康检查定时器
  void _startForegroundHealthCheckTimer() {
    _foregroundHealthTimer?.cancel();
    _foregroundHealthTimer = Timer.periodic(_foregroundHealthCheckInterval, (_) {
      if (!_isAppInForeground) {
        return;
      }
      unawaited(_checkServerHealth(ServerType.wall));
      unawaited(_checkServerHealth(ServerType.desktop));
    });
  }

  /// 停止前台连接健康检查定时器
  void _stopForegroundHealthCheckTimer() {
    _foregroundHealthTimer?.cancel();
    _foregroundHealthTimer = null;
  }

  /// 处理应用生命周期变化（前后台切换时恢复/收敛连接）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _startForegroundHealthCheckTimer();
      // 关键逻辑：部分机型息屏/亮屏可能不会稳定触发 paused，仅有 resumed；
      // 这里统一执行一次唤醒恢复流程，内部再根据连接状态与节流策略决定是否真正发起重连。
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      _lastForegroundResumedMs = nowMs;
      // 关键逻辑：部分设备解锁过程中会连续触发多次 resumed；这里做短去抖，避免重复唤醒恢复导致日志与连接抖动。
      if (nowMs - _lastResumeRecoverTriggeredMs >= _resumeRecoverDebounce.inMilliseconds) {
        _lastResumeRecoverTriggeredMs = nowMs;
        unawaited(_handleAppResumed());
      }
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // 关键逻辑：inactive 可能出现在权限弹窗/系统遮罩等“短暂非交互”场景；
      // 不应把它当作真正进入后台，否则会误关自动重连并影响前台体验。
      _handleAppBackgrounded(state);
    }
  }

  /// 应用回到前台时，按策略快速恢复服务器连接
  Future<void> _handleAppResumed() async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int pausedAtMs = _lastAppPausedMs;
    final int backgroundDurationMs = pausedAtMs <= 0 ? 0 : (nowMs - pausedAtMs).clamp(0, 1 << 30);
    // 关键逻辑：只对“真正从后台回到前台”的场景做恢复；恢复开始后清空标记，避免后续重复触发。
    _lastAppPausedMs = 0;

    Future<void> recoverOne(ServerType serverType) async {
      final endpoint = _endpoint(serverType);
      final bool connected = _clientManager.getClient(serverType).isConnected;

      final bool rxExpired = endpoint.lastMessageReceivedMs > 0 &&
          (nowMs - endpoint.lastMessageReceivedMs) > _foregroundRxStaleThreshold.inMilliseconds;
      final bool backgroundLongEnough = backgroundDurationMs > _resumeForceRecoverThreshold.inMilliseconds;

      // 关键逻辑：锁屏/休眠后 TCP 可能处于“假连接”状态，恢复前台时主动刷新连接更稳。
      final bool forceRefresh = connected && (rxExpired || backgroundLongEnough);
      // 关键逻辑：仍处于连接且无“疑似假连接”信号时，不做额外 ensure，避免无意义的连接流程开销。
      if (connected && !forceRefresh) {
        return;
      }
      await _maybeRecoverConnection(
        serverType,
        reason: '唤醒恢复',
        forceDisconnect: forceRefresh,
        udpFallback: true,
      );
    }

    await Future.wait<void>(<Future<void>>[
      recoverOne(ServerType.wall),
      recoverOne(ServerType.desktop),
    ]);
  }

  /// 应用进入后台时，关闭自动重连并停止前台健康检查以降低耗电
  void _handleAppBackgrounded(AppLifecycleState state) {
    _isAppInForeground = false;
    _lastAppPausedMs = DateTime.now().millisecondsSinceEpoch;
    _stopForegroundHealthCheckTimer();

    // 关键逻辑：后台阶段系统可能限制网络与定时器，继续自动重连通常只会耗电且无收益。
    _clientManager.setAutoReconnectEnabled(ServerType.wall, false);
    _clientManager.setAutoReconnectEnabled(ServerType.desktop, false);
  }

  /// 按节流策略触发指定链路的恢复连接
  Future<void> _maybeRecoverConnection(
    ServerType serverType, {
    required String reason,
    required bool forceDisconnect,
    required bool udpFallback,
  }) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final endpoint = _endpoint(serverType);
    if (nowMs - endpoint.lastHealthRecoverTriggeredMs < _recoverThrottle.inMilliseconds) {
      return;
    }
    endpoint.lastHealthRecoverTriggeredMs = nowMs;

    DebugUtils.log(
      '$reason->尝试连接|${serverType.displayName}',
      name: 'socket',
    );
    try {
      final bool ok = await ensureConnected(
        serverType,
        // 关键逻辑：唤醒恢复允许 UDP 兜底，解决“长时间息屏后历史链路失效但重开 App 可连上”的问题；
        // 健康检查仍可按调用方传入 false，避免频繁广播。
        udpFallback: udpFallback,
        // 关键逻辑：优先尝试 reconnect（更快），失败再对历史 IP 做有限次直连。
        preferReconnect: true,
        lastEndpointAttempts: 2,
        // 关键逻辑：当检测到“疑似假连接”时，先断开再恢复，避免 reconnect 被假连接短路。
        forceDisconnect: forceDisconnect,
        // 关键逻辑：唤醒恢复/健康检查只做“有限次主动恢复”，失败时不应触发底层持续自动重连（避免锁屏后开屏出现大量重连日志与耗电）。
        autoReconnect: false,
        connectTimeout: const Duration(seconds: 2),
        udpTimeout: const Duration(seconds: 2),
        // 关键逻辑：恢复策略优先级应低于“开关/启动”，避免并发时互相打断。
        priority: 3,
        source: reason,
      );
      final bool connectedNow = _clientManager.getClient(serverType).isConnected;
      // 关键逻辑：本次恢复若成功，则恢复底层自动重连能力；若失败保持关闭，避免后台持续重试。
      if (ok && connectedNow) {
        _clientManager.setAutoReconnectEnabled(serverType, true);
      }
      // 关键逻辑：连接日志只在“触发点”输出一次；内部 ensureConnected 可能多次重试，不应刷屏。
      DebugUtils.log(
        '$reason->连接结果|${serverType.displayName}|${(ok && connectedNow) ? "成功" : "失败"}',
        name: 'socket',
      );
    } catch (_) {
      DebugUtils.log(
        '$reason->连接结果|${serverType.displayName}|失败',
        name: 'socket',
      );
    }
  }

  /// 检查指定服务器链路是否“疑似假连接”，必要时触发恢复
  Future<void> _checkServerHealth(ServerType serverType) async {
    if (!_isAppInForeground) {
      return;
    }
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastForegroundResumedMs <= 0 ||
        (nowMs - _lastForegroundResumedMs) > _foregroundHealthCheckActiveWindow.inMilliseconds) {
      return;
    }
    final client = _clientManager.getClient(serverType);
    if (!client.isConnected) {
      return;
    }

    final endpoint = _endpoint(serverType);
    if (endpoint.lastMessageReceivedMs <= 0) {
      return;
    }

    final int silentMs = nowMs - endpoint.lastMessageReceivedMs;
    if (silentMs <= _foregroundRxStaleThreshold.inMilliseconds) {
      return;
    }

    // 关键逻辑：健康检查只在“唤醒后短窗口”内最多触发一次，避免服务器长期无上行消息导致反复断开重连。
    _lastForegroundResumedMs = 0;
    await _maybeRecoverConnection(
      serverType,
      reason: '健康检查',
      forceDisconnect: true,
      udpFallback: false,
    );
  }

  /// 按“单次连接会话”去重发送课程列表请求
  void _requestCourseListOncePerConnection(ServerType serverType) {
    final endpoint = _endpoint(serverType);
    if (endpoint.hasRequestedCourseListInCurrentConnection) {
      return;
    }
    // 关键逻辑：同一次 TCP 连接建立过程中，connect() 返回与 connected 状态回调可能同时触发；
    // 这里用 endpoint 级别标记确保每次连接只发送一次 CourseList。
    endpoint.hasRequestedCourseListInCurrentConnection = true;
    requestCourseList(serverType);
  }

  /// 点击触发的单次连接尝试：先尝试底层 reconnect 一次，再用历史 IP 直连 2 次，必要时 UDP 兜底
  ///
  /// 说明：
  /// - 用于“用户操作时若未连接，立刻提示失败，但后台做一次连接准备”的场景
  /// - 不开启自动重连，避免后台持续重连造成耗电/耗网
  /// - 当历史 IP 类型不匹配或不可达时，允许当次 UDP 发现兜底，减少“点击一次就失败”的体感
  /// - 关键逻辑：走 ensureConnected 的并发去重与优先级仲裁，避免与启动/开关触发的连接并发时重复 connect
  Future<bool> connectOncePreferLastEndpointThenUdp(
    ServerType serverType, {
    Duration connectTimeout = const Duration(seconds: 2),
  }) {
    // 关键逻辑：已连接时无需触发连接流程与日志输出，避免误导为“又发起了一次连接”。
    if (_clientManager.getClient(serverType).isConnected) {
      return Future<bool>.value(true);
    }
    DebugUtils.log(
      '课程详情->尝试连接|${serverType.displayName}',
      name: 'socket',
    );
    return ensureConnected(
      serverType,
      // 关键逻辑：课程连接场景也允许 UDP 兜底，确保历史 IP 不可用/类型迁移后可在当次恢复连接。
      udpFallback: true,
      preferReconnect: true,
      lastEndpointAttempts: 2,
      autoReconnect: false,
      connectTimeout: connectTimeout,
      udpTimeout: connectTimeout,
      priority: 3,
      source: '课程详情',
    ).then((ok) {
      final bool connectedNow = _clientManager.getClient(serverType).isConnected;
      DebugUtils.log(
        '课程详情连接结果|${serverType.displayName}|${(ok && connectedNow) ? "成功" : "失败"}',
        name: 'socket',
      );
      return ok;
    }).catchError((_) {
      DebugUtils.log(
        '课程详情连接结果|${serverType.displayName}|失败',
        name: 'socket',
      );
      return false;
    });
  }

  /// 获取本机当前可用的 IPv4 局域网网段信息（IP/掩码/网络地址）
  Future<List<LanIpv4Network>> _localIpv4Networks() async {
    return LanIpv4Utils.localNetworks();
  }

  /// 判断目标服务器 IP 是否与本机处于同一局域网
  Future<bool> _isServerInSameLan(String host) async {
    final List<LanIpv4Network> localNetworks = await _localIpv4Networks();
    if (localNetworks.isEmpty) {
      // 关键逻辑：没有本机网段信息时无法做“掩码位运算”准确判定，按安全策略拒绝连接。
      return false;
    }
    // 关键逻辑：通过“(目标IP & 本机掩码) == 本机网络地址”做真实同网段判断，兼容 /23、/24 等掩码。
    return LanIpv4Utils.isInSameLan(host, localNetworks);
  }

  @override
  void onInit() {
    super.onInit();
    _initClientManager();
    _initDiscoveryService();
    _initLifecycleAndHealthCheck();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundHealthCheckTimer();
    super.onClose();
  }

  // ==================== 服务器发现 ====================

  /// 扫描局域网内的服务器
  Future<List<DiscoveredServer>> scanForServers({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    isScanning.value = true;
    discoveredServers.clear();

    final servers = await _discoveryService.startDiscovery(
      timeout: timeout,
      retryCount: 3,
    );

    isScanning.value = false;
    return servers;
  }

  /// 主动停止正在进行的 UDP 扫描
  ///
  /// 说明：
  /// - 仅停止发现流程，不影响已建立的 TCP 连接
  /// - 用于页面退出/用户取消等场景，避免长时间等待
  // ==================== 连接管理 ====================

  /// 连接到指定服务器
  ///
  /// 说明：
  /// - [autoReconnect] 控制断线后是否自动重连（启动阶段可关闭，业务阶段建议开启）
  /// - 连接成功后会持久化 IP/端口，供下次启动直接直连
  Future<bool> connect(
    ServerType serverType,
    String host,
    int port, {
    bool autoReconnect = true,
    Duration? connectTimeout,
  }) async {
    if (!await _isServerInSameLan(host)) {
      // 关键逻辑：只允许连接“当前本机所在网段”内的服务器，避免跨网段误连旧场地设备。
      final List<LanIpv4Network> localNetworks = await _localIpv4Networks();
      final String networksDesc = LanIpv4Utils.formatNetworksForLog(localNetworks);
      DebugUtils.log('拒绝连接：目标服务器不在同一局域网内，host=$host, localNetworks=[$networksDesc]', name: 'socket');
      return false;
    }
    final success =
        await _clientManager.connect(serverType, host, port, autoReconnect: autoReconnect, timeout: connectTimeout);
    if (success) {
      _endpoint(serverType).connectedServerIp.value = host;
      unawaited(_persistLastServerEndpoint(serverType, host, port));
    }
    return success;
  }

  /// 启动阶段恢复连接（历史 IP 优先，必要时短 UDP 扫描兜底）
  ///
  /// 说明：
  /// - 目标：解决“设备已开→App 后开”导致的未连接问题
  /// - 策略：每次尝试都走 ensureConnected（历史 IP 直连 → UDP 扫描兜底），并利用其并发去重
  /// - 额外约束：本次启动恢复流程中最多只做一次 UDP 扫描，其它尝试复用扫描结果
  Future<Map<ServerType, bool>> recoverConnectionsAtStartup({
    int attempts = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Duration udpTimeout = const Duration(seconds: 2),
  }) async {
    Future<List<DiscoveredServer>>? startupScanFuture;
    // 启动恢复专用：最多只触发一次 UDP 扫描，避免每轮尝试都广播造成额外开销。
    Future<List<DiscoveredServer>> startupScanOnce() {
      startupScanFuture ??= _scanForServersOnce(timeout: udpTimeout).then((servers) {
        return servers;
      }).catchError((e) {
        // 关键逻辑：扫描异常不应中断启动恢复重试；兜底为空列表让后续按失败处理并继续下一轮。
        return <DiscoveredServer>[];
      });
      return startupScanFuture!;
    }

    // 关键逻辑：先用一次 UDP 扫描对齐“历史 IP -> 实际服务端类型”；
    // 若发现墙/桌历史 IP 指向了错误类型，先清错链路缓存并迁移到正确类型，避免后续仍按错误类型直连。
    final startupDiscoveredServers = await startupScanOnce();
    await _reconcileCachedEndpointsWithDiscoveredServers(startupDiscoveredServers);

    // 启动恢复单条链路连接：通过 ensureConnected 复用“历史 IP + UDP 兜底”，并避免与其它触发点并发冲突。
    Future<bool> recoverOne(ServerType serverType) async {
      if (_clientManager.getClient(serverType).isConnected) {
        return true;
      }

      DebugUtils.log(
        'app启动->尝试连接|${serverType.displayName}',
        name: 'socket',
      );
      for (var i = 0; i < attempts; i++) {
        bool ok = false;
        try {
          ok = await ensureConnected(
            serverType,
            // 关键逻辑：启动恢复属于“有限次尝试”，不应该开启底层自动重连；否则即使上层停止重试，
            // 也可能在后台持续打印“第 N 次重连”并造成耗电/耗网。
            autoReconnect: false,
            udpTimeout: udpTimeout,
            scanOnceOverride: startupScanOnce,
            priority: 2,
            source: 'app启动',
            // 关键逻辑：确保单次尝试不会无限挂起；否则会导致后续第2/3次重试永远不执行。
          );
        } catch (e) {
          // 关键逻辑：任何异常都不应打断启动恢复的重试循环，避免出现“只跑了 1/3 次”的情况。
          ok = false;
        }

        if (ok && _clientManager.getClient(serverType).isConnected) {
          // 关键逻辑：启动阶段“连接成功后”再开启自动重连，用于后续断线恢复。
          _clientManager.setAutoReconnectEnabled(serverType, true);
          return true;
        }
        // 关键逻辑：兜底防御——确保本轮失败后不遗留任何自动重连定时器。
        _clientManager.setAutoReconnectEnabled(serverType, false);
        if (i < attempts - 1) {
          await Future.delayed(retryDelay);
        }
      }
      return _clientManager.getClient(serverType).isConnected;
    }

    /// 安全执行启动恢复单链路连接：捕获异常并返回当前连接状态
    Future<bool> safeRecoverOne(ServerType serverType) async {
      try {
        return await recoverOne(serverType);
      } catch (e) {
        return _clientManager.getClient(serverType).isConnected;
      }
    }

    // 关键逻辑：墙/桌并发恢复以缩短启动等待时间；同时用 safeRecoverOne 确保互不影响。
    final results = await Future.wait<bool>([
      safeRecoverOne(ServerType.wall),
      safeRecoverOne(ServerType.desktop),
    ]);
    final bool wallOk = results[0];
    final bool desktopOk = results[1];
    DebugUtils.log(
      'app启动连接结果|${ServerType.wall.displayName}=${wallOk ? "成功" : "失败"}|${ServerType.desktop.displayName}=${desktopOk ? "成功" : "失败"}',
      name: 'socket',
    );
    return {ServerType.wall: wallOk, ServerType.desktop: desktopOk};
  }

  /// 用 UDP 发现结果校准历史端点缓存：类型不匹配时清理错误链路并迁移到正确链路
  Future<void> _reconcileCachedEndpointsWithDiscoveredServers(List<DiscoveredServer> servers) async {
    Future<void> reconcileOne(ServerType cachedType) async {
      final cached = _loadLastServerEndpoint(cachedType);
      if (cached == null) {
        return;
      }
      final discovered = _pickDiscoveredServerByIp(servers, cached.ip);
      if (discovered == null) {
        return;
      }
      final CLIENTEND expectedType = cachedType.toClientEnd();
      if (discovered.serverType == expectedType) {
        return;
      }
      final ServerType? migratedType = _tryMapClientEndToServerType(discovered.serverType);
      // 关键逻辑：发现“历史链路类型 != 实际服务端类型”时，必须先清理错误链路缓存，避免继续误连。
      await _clearLastServerEndpoint(cachedType);
      // 关键逻辑：若能识别出实际类型，则把该 IP 迁移到正确链路缓存，保证下一步按正确类型连接。
      if (migratedType != null) {
        await _persistLastServerEndpoint(migratedType, discovered.ipAddress, discovered.tcpPort);
        DebugUtils.log(
          '启动前缓存校准：已迁移历史IP|${cachedType.displayName}->${migratedType.displayName}|ip=${discovered.ipAddress}',
          name: 'socket',
        );
      } else {
        DebugUtils.log(
          '启动前缓存校准：已清理异常类型历史IP|${cachedType.displayName}|ip=${cached.ip}',
          name: 'socket',
        );
      }
    }

    await reconcileOne(ServerType.wall);
    await reconcileOne(ServerType.desktop);
  }

  /// 校验历史缓存 IP 的实际服务端类型，必要时执行“清理错误缓存 + 迁移到正确类型”
  Future<bool> _validateAndMaybeMigrateCachedEndpointByIp({
    required ServerType serverType,
    required String ip,
    required int fallbackPort,
    required Duration udpTimeout,
    required Future<List<DiscoveredServer>> Function()? scanOnceOverride,
    bool forceFreshScan = false,
    bool requireKnownType = false,
    bool recoverMigratedTypeNow = false,
  }) async {
    List<DiscoveredServer> servers;
    try {
      if (forceFreshScan) {
        // 关键逻辑：连接后类型复核需要拿到“当前最新”的服务端类型，不能复用可能过期的 inFlight 扫描结果。
        servers = await scanForServers(timeout: udpTimeout);
      } else {
        servers = await (scanOnceOverride?.call() ?? _scanForServersOnce(timeout: udpTimeout));
      }
    } catch (_) {
      return true;
    }
    final discovered = _pickDiscoveredServerByIp(servers, ip);
    if (discovered == null) {
      // 关键逻辑：未发现“该 IP 的当前服务器响应”时，不应清理历史缓存；
      // 这通常只是目标服务器未开启/网络瞬时丢包，不能据此判定类型已变化。
      if (requireKnownType) {
        DebugUtils.log(
          '历史IP类型校验：未识别到该IP的当前类型，保留缓存并等待下次校验|${serverType.displayName}|ip=$ip',
          name: 'socket',
        );
      }
      return true;
    }
    final CLIENTEND expectedType = serverType.toClientEnd();
    if (discovered.serverType == expectedType) {
      return true;
    }
    final ServerType? migratedType = _tryMapClientEndToServerType(discovered.serverType);
    // 关键逻辑：历史 IP 实际类型与目标链路不一致时，必须立刻清理错误链路缓存，避免继续误连。
    await _clearLastServerEndpoint(serverType);
    // 关键逻辑：若识别出真实类型，则把同一 IP 迁移到真实链路缓存，下一次优先按正确类型直连。
    if (migratedType != null) {
      await _persistLastServerEndpoint(
        migratedType,
        discovered.ipAddress,
        discovered.tcpPort > 0 ? discovered.tcpPort : fallbackPort,
      );
      DebugUtils.log(
        '历史IP类型校验：已迁移缓存|${serverType.displayName}->${migratedType.displayName}|ip=${discovered.ipAddress}',
        name: 'socket',
      );
      // 关键逻辑：当“当前链路类型”被判定为错误且已迁移到另一链路时，立即触发目标链路恢复，
      // 避免只看到“旧链路断开”而没有“新链路连上”的状态反馈。
      if (recoverMigratedTypeNow && migratedType != serverType && _isAppInForeground) {
        unawaited(_recoverMigratedServerType(migratedType));
      }
    } else {
      DebugUtils.log(
        '历史IP类型校验：已清理异常缓存|${serverType.displayName}|ip=$ip',
        name: 'socket',
      );
    }
    return false;
  }

  /// 业务强关联：确保指定类型服务器已连接（历史 IP 优先，必要时 UDP 扫描兜底）
  ///
  /// 说明：
  /// - 用于“用户点击打开设备/课程”等动作触发
  /// - 内部做了并发去重：同一类型同时触发只会跑一次
  Future<bool> ensureConnected(
    ServerType serverType, {
    bool autoReconnect = true,
    bool udpFallback = true,
    bool preferReconnect = false,
    int lastEndpointAttempts = 1,
    bool forceDisconnect = false,
    Duration? connectTimeout,
    Duration udpTimeout = const Duration(seconds: 3),
    Future<List<DiscoveredServer>> Function()? scanOnceOverride,
    int priority = 2,
    String source = 'unknown',
  }) {
    // 关键逻辑：ensureConnected 内部可能因为“重试/并发去重/优先级抢占”而被多次调用；
    // 尝试连接/连接结果日志应由各个“触发点”（启动/开关/课程详情/健康检查等）统一输出一次，避免刷屏。
    final currentSession = _ensureConnectSessions[serverType];
    final inFlight = _ensureConnectInFlight[serverType];
    if (inFlight != null && currentSession != null) {
      if (priority < currentSession.priority) {
        currentSession.cancelled = true;
        if (_ensureConnectInFlight[serverType] == inFlight) {
          _ensureConnectInFlight.remove(serverType);
        }
      } else {
        return inFlight;
      }
    } else if (inFlight != null) {
      return inFlight;
    }

    final session = _EnsureConnectSession(
      id: ++_ensureConnectSessionSeq,
      priority: priority,
      source: source,
      autoReconnect: autoReconnect,
      udpFallback: udpFallback,
      preferReconnect: preferReconnect,
      lastEndpointAttempts: lastEndpointAttempts,
      forceDisconnect: forceDisconnect,
      connectTimeout: connectTimeout,
      udpTimeout: udpTimeout,
    );
    _ensureConnectSessions[serverType] = session;

    final Future<bool> future = _ensureConnectedInternal(
      serverType,
      autoReconnect: autoReconnect,
      udpFallback: udpFallback,
      preferReconnect: preferReconnect,
      lastEndpointAttempts: lastEndpointAttempts,
      forceDisconnect: forceDisconnect,
      connectTimeout: connectTimeout,
      udpTimeout: udpTimeout,
      scanOnceOverride: scanOnceOverride,
      sessionId: session.id,
    );
    _ensureConnectInFlight[serverType] = future;
    future.whenComplete(() {
      if (_ensureConnectInFlight[serverType] == future) {
        _ensureConnectInFlight.remove(serverType);
      }
      final cur = _ensureConnectSessions[serverType];
      if (cur != null && cur.id == session.id) {
        _ensureConnectSessions.remove(serverType);
      }
    });
    return future.then((ok) {
      if (session.cancelled) {
        return false;
      }
      final stillCurrent = _ensureConnectSessions[serverType]?.id == session.id;
      final bool connectedNow = _clientManager.getClient(serverType).isConnected;
      final bool okNow = ok && connectedNow;
      if (stillCurrent && okNow) {
        _clientManager.setAutoReconnectEnabled(serverType, session.autoReconnect);
      } else if (stillCurrent && !session.autoReconnect) {
        _clientManager.setAutoReconnectEnabled(serverType, false);
      }
      return ok;
    });
  }

  /// ensureConnected 的内部实现
  ///
  /// 说明：
  /// - 先尝试历史 IP 直连（由 [autoReconnect] 决定是否启用底层自动重连）
  /// - 失败后进行 UDP 扫描并连接（由 [autoReconnect] 决定是否启用底层自动重连）
  Future<bool> _ensureConnectedInternal(
    ServerType serverType, {
    required bool autoReconnect,
    required bool udpFallback,
    required bool preferReconnect,
    required int lastEndpointAttempts,
    required bool forceDisconnect,
    required Duration? connectTimeout,
    required Duration udpTimeout,
    Future<List<DiscoveredServer>> Function()? scanOnceOverride,
    required int sessionId,
  }) async {
    if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
      return false;
    }
    if (_clientManager.getClient(serverType).isConnected) {
      return true;
    }

    final endpoint = _loadLastServerEndpoint(serverType);
    if (forceDisconnect) {
      // 关键逻辑：仅当本次会话被调度执行时才做断开，避免复用 inFlight 时误断其它高优先级连接流程。
      _clientManager.disconnect(serverType);
    }

    if (endpoint == null) {
      // 关键逻辑：无历史 IP 且禁止 UDP 兜底时直接返回，避免无意义扫描与广播。
      if (!udpFallback) {
        return false;
      }
    } else {
      if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
        return false;
      }
      final bool allowConnect = await _isServerInSameLan(endpoint.ip);
      if (!allowConnect) {
        final List<LanIpv4Network> localNetworks = await _localIpv4Networks();
        final String networksDesc = LanIpv4Utils.formatNetworksForLog(localNetworks);
        // 关键逻辑：这里的失败原因包括“目标不在同网段”或“本机网段信息暂不可用”，输出本机网段详情便于现场快速定位。
        DebugUtils.log(
          '跳过历史IP直连：不在同一局域网或本机网段不可用，serverType=$serverType, ip=${endpoint.ip}, localNetworks=[$networksDesc]',
          name: 'socket',
        );
        if (!udpFallback) {
          return false;
        }
      } else {
        final bool shouldApplyHistoricalTypeCheck = _shouldApplyHistoricalTypeCheck(serverType);
        if (shouldApplyHistoricalTypeCheck) {
          final bool endpointTypeMatched = await _validateAndMaybeMigrateCachedEndpointByIp(
            serverType: serverType,
            ip: endpoint.ip,
            fallbackPort: endpoint.port,
            udpTimeout: udpTimeout,
            scanOnceOverride: scanOnceOverride,
            requireKnownType: udpFallback,
            recoverMigratedTypeNow: true,
          );
          if (!endpointTypeMatched) {
            // 关键逻辑：历史 IP 被识别为“另一类型服务器”时，本次不再继续直连旧链路；
            // 让流程回落到 UDP 兜底（或按调用方策略失败返回），避免把桌面误当墙面连上。
            if (!udpFallback) {
              return false;
            }
          } else {
            if (preferReconnect) {
              final bool reconnectOk = await _clientManager.reconnect(
                serverType,
                timeout: connectTimeout,
              );
              if (reconnectOk && _clientManager.getClient(serverType).isConnected) {
                return true;
              }
            }

            final int attempts = lastEndpointAttempts <= 0 ? 1 : lastEndpointAttempts;
            for (int i = 0; i < attempts; i++) {
              if (_ensureConnectSessions[serverType]?.id != sessionId ||
                  (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
                return false;
              }
              final ok = await connect(
                serverType,
                endpoint.ip,
                endpoint.port,
                autoReconnect: autoReconnect,
                connectTimeout: connectTimeout,
              );
              if (ok) {
                return true;
              }
            }
          }
        } else {
          if (preferReconnect) {
            final bool reconnectOk = await _clientManager.reconnect(
              serverType,
              timeout: connectTimeout,
            );
            if (reconnectOk && _clientManager.getClient(serverType).isConnected) {
              return true;
            }
          }

          final int attempts = lastEndpointAttempts <= 0 ? 1 : lastEndpointAttempts;
          for (int i = 0; i < attempts; i++) {
            if (_ensureConnectSessions[serverType]?.id != sessionId ||
                (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
              return false;
            }
            final ok = await connect(
              serverType,
              endpoint.ip,
              endpoint.port,
              autoReconnect: autoReconnect,
              connectTimeout: connectTimeout,
            );
            if (ok) {
              return true;
            }
          }
        }
      }
    }

    if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
      return false;
    }
    if (!udpFallback) {
      return false;
    }
    // 兜底：UDP 扫描获取服务器 IP
    // 关键逻辑：允许上层复用扫描结果（例如启动恢复阶段限制“最多扫一次”），避免重复广播。
    final servers = await (scanOnceOverride?.call() ?? _scanForServersOnce(timeout: udpTimeout));
    if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
      return false;
    }
    final discovered = _pickDiscoveredServer(servers, serverType);
    if (discovered == null) {
      return false;
    }
    return await connect(
      serverType,
      discovered.ipAddress,
      discovered.tcpPort,
      autoReconnect: autoReconnect,
      connectTimeout: connectTimeout,
    );
  }

  /// 读取历史服务器端点（IP/端口）
  ///
  /// 说明：
  /// - IP 为空表示没有缓存，不返回默认值，交由上层决定是否 UDP 扫描
  ({String ip, int port})? _loadLastServerEndpoint(ServerType serverType) {
    final storage = Storage();
    final ipKey = _ipStorageKey(serverType);
    final portKey = _portStorageKey(serverType);

    final ip = storage.getString(ipKey);
    if (ip.isEmpty) {
      return null;
    }

    final portStr = storage.getString(portKey);
    final port = int.tryParse(portStr) ?? 8000;
    return (ip: ip, port: port);
  }

  /// 持久化服务器端点（IP/端口）
  ///
  /// 说明：
  /// - 用于下次启动优先走 TCP 直连，减少 UDP 扫描次数
  Future<void> _persistLastServerEndpoint(ServerType serverType, String host, int port) async {
    final storage = Storage();
    await storage.setString(_ipStorageKey(serverType), host);
    await storage.setString(_portStorageKey(serverType), port.toString());
  }

  /// 清理指定服务器类型的历史端点缓存（IP/端口）
  Future<void> _clearLastServerEndpoint(ServerType serverType) async {
    final storage = Storage();
    await storage.remove(_ipStorageKey(serverType));
    await storage.remove(_portStorageKey(serverType));
  }

  /// 获取对应服务器的 IP 存储 Key
  String _ipStorageKey(ServerType serverType) {
    switch (serverType) {
      case ServerType.wall:
        return _lastWallServerIpKey;
      case ServerType.desktop:
        return _lastDesktopServerIpKey;
    }
  }

  /// 获取对应服务器的端口存储 Key
  String _portStorageKey(ServerType serverType) {
    switch (serverType) {
      case ServerType.wall:
        return _lastWallServerPortKey;
      case ServerType.desktop:
        return _lastDesktopServerPortKey;
    }
  }

  /// 扫描复用：同一时刻只进行一次 UDP 发现
  ///
  /// 说明：
  /// - 避免多处触发扫描导致广播过多、扫描状态抖动
  Future<List<DiscoveredServer>> _scanForServersOnce({required Duration timeout}) {
    final inFlight = _scanServersInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = scanForServers(timeout: timeout).whenComplete(() {
      _scanServersInFlight = null;
    });
    _scanServersInFlight = future;
    return future;
  }

  /// 从扫描结果中挑选指定 ServerType 的服务器
  DiscoveredServer? _pickDiscoveredServer(List<DiscoveredServer> servers, ServerType serverType) {
    final target = serverType.toClientEnd();
    for (final s in servers) {
      if (s.serverType == target) {
        return s;
      }
    }
    return null;
  }

  /// 从扫描结果中按 IP 查找服务器
  DiscoveredServer? _pickDiscoveredServerByIp(List<DiscoveredServer> servers, String ip) {
    for (final s in servers) {
      if (s.ipAddress == ip) {
        return s;
      }
    }
    return null;
  }

  /// 尝试将协议层 CLIENTEND 安全映射为业务层 ServerType；未知值返回 null
  ServerType? _tryMapClientEndToServerType(CLIENTEND clientEnd) {
    switch (clientEnd) {
      case CLIENTEND.WALL:
        return ServerType.wall;
      case CLIENTEND.Desktop:
        return ServerType.desktop;
      default:
        return null;
    }
  }

  /// 断开服务器连接
  void disconnect(ServerType serverType) {
    _clientManager.disconnect(serverType);
  }

  /// 断开所有服务器
  void disconnectAll() {
    _clientManager.disconnectAll();
  }

  void _initClientManager() {
    _clientManager = SocketClientManager();

    _clientManager.onStateChanged = _onServerStateChanged;
    _clientManager.onMessageReceived = _onServerMessageReceived;

    _clientManager.onError = (serverType, error) {
      final String msg = error.toString();
      if (msg.contains('Connection timed out') || msg.contains('timed out') || msg.contains('errno = 110')) {
        // 关键逻辑：连接超时属于常见的网络波动/设备未开机场景；该错误会被频繁触发并刷屏，因此按需求不输出。
        return;
      }
      DebugUtils.log('${serverType.displayName}错误: $error', name: 'socket');
      //Get.snackbar('${serverType.displayName}错误', error);
    };
  }

  void _initDiscoveryService() {
    _discoveryService = UdpDiscoveryService();

    _discoveryService.onServerDiscovered = (server) {
      if (!discoveredServers.contains(server)) {
        discoveredServers.add(server);
      }
    };

    _discoveryService.onScanComplete = (servers) {
      isScanning.value = false;
    };
  }

  void _onServerStateChanged(ServerType serverType, SocketState state) {
    final endpoint = _endpoint(serverType);
    if (state == SocketState.connecting || state == SocketState.disconnected || state == SocketState.failed) {
      endpoint.connectionState.value = state;
      endpoint.isAwaitingTypeConfirmation = false;
      // 关键逻辑：一旦进入新一轮连接尝试（或连接失败/断开），需要重置标记，确保下次 connected 会补发一次课程列表。
      endpoint.hasRequestedCourseListInCurrentConnection = false;
      // 关键逻辑：连接状态变化时重置接收时间戳，避免前台健康检查误判为“长期无消息”。
      endpoint.lastMessageReceivedMs = 0;
    }
    if (state == SocketState.disconnected) {
      endpoint.connectedServerIp.value = null;
      endpoint.isAwaitingTypeConfirmation = false;
    }
    if (state == SocketState.connected) {
      final bool shouldConfirmTypeBeforeConnected = _shouldConfirmTypeBeforeConnected(serverType);
      if (shouldConfirmTypeBeforeConnected) {
        // 关键逻辑：仅在“业务侧 ensureConnected 流程”中启用类型确认门禁；
        // 底层自动重连不走该门禁，避免你反馈的“切换类型后仍卡在旧链路显示”的问题。
        endpoint.connectionState.value = SocketState.connecting;
        endpoint.isAwaitingTypeConfirmation = true;
      } else {
        endpoint.isAwaitingTypeConfirmation = false;
        endpoint.connectionState.value = SocketState.connected;
        endpoint.lastConnectedMs = DateTime.now().millisecondsSinceEpoch;
        _requestCourseListOncePerConnection(serverType);
      }
      if (endpoint.connectedServerIp.value == null) {
        final cached = _loadLastServerEndpoint(serverType);
        if (cached != null) {
          endpoint.connectedServerIp.value = cached.ip;
        }
      }
      sendHeartbeat(serverType);
      if (shouldConfirmTypeBeforeConnected) {
        unawaited(_confirmTypeOrFallback(serverType));
      }
    }
    //当所有服务器连接都断开时，重置课程列表相关的 UI 状态 。
    /*if (!_clientManager.isAnyConnected) {
      isCourseListLoading.value = true;
      courseList.clear();
    }*/
  }

  void _onServerMessageReceived(ServerType serverType, MESSAGE message) {
    if (!_validateServerTypeByHeartbeat(serverType, message)) {
      return;
    }
    final endpoint = _endpoint(serverType);
    // 关键逻辑：收到任意消息（含 HeartEcho）就刷新接收时间戳，用于前台“假连接”检测。
    endpoint.lastMessageReceivedMs = DateTime.now().millisecondsSinceEpoch;
    endpoint.messageController.add(message);
    _allMessageController.add((serverType, message));
    _handleMessage(serverType, message);
  }

  /// 基于心跳回包校验服务端类型，若类型不匹配则断开并清理该链路历史 IP 缓存
  bool _validateServerTypeByHeartbeat(ServerType serverType, MESSAGE message) {
    final endpoint = _endpoint(serverType);
    // 关键逻辑：类型确认策略仅在“启动恢复且等待确认”阶段生效；
    // 设备开关/课程连接/底层自动重连保持原始行为，不做该拦截与迁移。
    if (!endpoint.isAwaitingTypeConfirmation) {
      return true;
    }
    if (message.mSGtype != MSGTYPE.HeartEcho) {
      return false;
    }
    if (!message.hasEchoData() || !message.echoData.hasClientEnd()) {
      return false;
    }
    final CLIENTEND expectedClientEnd = serverType.toClientEnd();
    final CLIENTEND actualClientEnd = message.echoData.clientEnd;
    if (expectedClientEnd == actualClientEnd) {
      if (endpoint.isAwaitingTypeConfirmation && _clientManager.getClient(serverType).isConnected) {
        endpoint.isAwaitingTypeConfirmation = false;
        endpoint.connectionState.value = SocketState.connected;
        endpoint.lastConnectedMs = DateTime.now().millisecondsSinceEpoch;
        _requestCourseListOncePerConnection(serverType);
      }
      return true;
    }
    // 关键逻辑：若“墙/桌”链路收到的心跳类型与预期不一致，说明历史 IP 可能指向了错误服务端；
    // 立即清理该链路缓存并断开，避免下次启动继续用错误 IP 反复直连。
    final String? mismatchedIp = endpoint.connectedServerIp.value;
    final ServerType? migratedType = _tryMapClientEndToServerType(actualClientEnd);
    // 关键逻辑：当已明确对端真实类型时，把当前 IP 迁移到真实链路缓存，确保后续“新类型链路”可立即命中历史直连。
    if (mismatchedIp != null && mismatchedIp.isNotEmpty && migratedType != null && migratedType != serverType) {
      unawaited(_persistLastServerEndpoint(migratedType, mismatchedIp, 8000));
    }
    unawaited(_clearLastServerEndpoint(serverType));
    endpoint.isAwaitingTypeConfirmation = false;
    endpoint.connectedServerIp.value = null;
    _clientManager.disconnect(serverType);
    // 关键逻辑：类型不匹配后优先恢复“真实类型链路”；无法识别真实类型时，回退为原链路 UDP 纠偏。
    if (_isAppInForeground) {
      if (migratedType != null && migratedType != serverType) {
        unawaited(_recoverMigratedServerType(migratedType));
      } else {
        unawaited(_recoverConnectionAfterTypeMismatch(serverType));
      }
    }
    DebugUtils.log(
      '检测到服务端类型不匹配，已清理历史IP并断开|期望=${expectedClientEnd.name}|实际=${actualClientEnd.name}|链路=${serverType.displayName}',
      name: 'socket',
    );
    return false;
  }

  /// 服务端类型不匹配后的纠偏连接：按“无历史 IP”策略走 UDP 发现并尝试重连
  Future<void> _recoverConnectionAfterTypeMismatch(ServerType serverType) async {
    try {
      await ensureConnected(
        serverType,
        autoReconnect: false,
        udpFallback: true,
        preferReconnect: false,
        lastEndpointAttempts: 1,
        connectTimeout: const Duration(seconds: 2),
        udpTimeout: const Duration(seconds: 2),
        priority: 2,
        source: '类型校验纠偏',
      );
      // 关键逻辑：纠偏成功后恢复自动重连能力，保持与启动恢复成功后的行为一致。
      if (_clientManager.getClient(serverType).isConnected) {
        _clientManager.setAutoReconnectEnabled(serverType, true);
      }
    } catch (_) {}
  }

  /// 等待类型确认超时后的兜底：若仍处于连接且未拿到心跳类型，按可用性优先确认 connected
  Future<void> _confirmTypeOrFallback(ServerType serverType) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final endpoint = _endpoint(serverType);
    if (!endpoint.isAwaitingTypeConfirmation) {
      return;
    }
    if (!_clientManager.getClient(serverType).isConnected) {
      endpoint.isAwaitingTypeConfirmation = false;
      return;
    }
    final String? ip = endpoint.connectedServerIp.value;
    if (ip != null && ip.isNotEmpty) {
      final bool endpointTypeMatched = await _validateAndMaybeMigrateCachedEndpointByIp(
        serverType: serverType,
        ip: ip,
        fallbackPort: 8000,
        udpTimeout: const Duration(seconds: 2),
        scanOnceOverride: null,
        forceFreshScan: true,
        requireKnownType: false,
        recoverMigratedTypeNow: true,
      );
      if (!endpointTypeMatched) {
        // 关键逻辑：兜底超时阶段若已识别出“当前 IP 类型不匹配”，不能再回退为 connected，
        // 否则会出现“墙面已断开后立刻改桌面，UI 又显示墙面连接成功”的误报。
        endpoint.isAwaitingTypeConfirmation = false;
        endpoint.connectedServerIp.value = null;
        _clientManager.disconnect(serverType);
        return;
      }
    }
    // 关键逻辑：部分服务端在启动阶段可能延迟/漏发 HeartEcho，超时后先恢复可用连接，避免启动看起来“全未连接”。
    endpoint.isAwaitingTypeConfirmation = false;
    endpoint.connectionState.value = SocketState.connected;
    endpoint.lastConnectedMs = DateTime.now().millisecondsSinceEpoch;
    _requestCourseListOncePerConnection(serverType);
  }

  /// 判断当前连接是否应当启用“先类型确认再标记 connected”
  bool _shouldConfirmTypeBeforeConnected(ServerType serverType) {
    // 关键逻辑：该策略仅用于 app 启动恢复场景；
    // 设备开关与课程触发连接恢复原状（连接成功即标记 connected），避免影响交互响应速度。
    return _ensureConnectSessions[serverType]?.source == 'app启动';
  }

  /// 判断当前历史 IP 直连是否应启用“服务器类型一致性校验”
  bool _shouldApplyHistoricalTypeCheck(ServerType serverType) {
    return _ensureConnectSessions[serverType]?.source == 'app启动';
  }

  /// 当历史链路被迁移到另一服务类型后，主动尝试连接目标链路并恢复自动重连能力
  Future<void> _recoverMigratedServerType(ServerType serverType) async {
    try {
      final bool ok = await ensureConnected(
        serverType,
        autoReconnect: false,
        udpFallback: true,
        preferReconnect: true,
        lastEndpointAttempts: 2,
        connectTimeout: const Duration(seconds: 2),
        udpTimeout: const Duration(seconds: 3),
        priority: 1,
        source: '类型迁移恢复',
      );
      if (ok && _clientManager.getClient(serverType).isConnected) {
        _clientManager.setAutoReconnectEnabled(serverType, true);
      }
    } catch (_) {}
  }

  UdpDiscoveryService get discoveryService => _discoveryService;

  SocketClientManager get clientManager => _clientManager;
}
