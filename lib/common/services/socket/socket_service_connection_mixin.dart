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

  static const Duration _foregroundHealthCheckInterval = Duration(seconds: 10);
  static const Duration _foregroundRxStaleThreshold = Duration(seconds: 45);
  static const Duration _resumeForceRecoverThreshold = Duration(seconds: 25);
  static const Duration _recoverThrottle = Duration(seconds: 10);
  static const Duration _foregroundHealthCheckActiveWindow = Duration(seconds: 120);

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
      // 关键逻辑：App 冷启动也会收到 resumed；此时应交给启动恢复流程做“有限次尝试”，
      // 避免在服务器未开启时误触发底层自动重连（导致用户稍后开机时自动连上，看起来像“自己在重连”）。
      if (_lastAppPausedMs > 0) {
        // 关键逻辑：健康检查只在“刚从后台回到前台”的短窗口内启用，用于兜底识别“假连接”；
        // 长时间前台驻留时不应依赖“收包静默”判定，否则服务器无上行消息会导致反复触发重连与刷日志。
        _lastForegroundResumedMs = DateTime.now().millisecondsSinceEpoch;
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
        // 关键逻辑：健康检查/唤醒恢复属于“轻量恢复”，不做 UDP 扫描兜底，避免后台广播与耗电。
        udpFallback: false,
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

  /// 点击触发的单次连接尝试：先尝试底层 reconnect 一次，再用历史 IP 直连 2 次（不做 UDP 兜底）
  ///
  /// 说明：
  /// - 用于“用户操作时若未连接，立刻提示失败，但后台做一次连接准备”的场景
  /// - 不开启自动重连，避免后台持续重连造成耗电/耗网
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
      udpFallback: false,
      preferReconnect: true,
      lastEndpointAttempts: 2,
      autoReconnect: false,
      connectTimeout: connectTimeout,
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

  /// 获取本机当前可用的 IPv4 /24 网段前缀（例如 192.168.101）
  Future<List<String>> _localIpv4CClassPrefixes() async {
    try {
      final prefixes = <String>{};
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final itf in interfaces) {
        for (final addr in itf.addresses) {
          final ip = addr.address;
          if (!_isPrivateIpv4(ip)) {
            continue;
          }
          final parts = ip.split('.');
          if (parts.length != 4) {
            continue;
          }
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
      return prefixes.toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// 判断某个 IPv4 是否属于私有网段（RFC1918）
  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    if (a == 10) {
      return true;
    }
    if (a == 192 && b == 168) {
      return true;
    }
    if (a == 172 && b >= 16 && b <= 31) {
      return true;
    }
    return false;
  }

  /// 判断目标服务器 IP 是否与本机处于同一局域网（按 IPv4 前三段 /24 判断）
  Future<bool> _isServerInSameLan(String host) async {
    if (!_isPrivateIpv4(host)) {
      return false;
    }
    final parts = host.split('.');
    if (parts.length != 4) {
      return false;
    }
    final String prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final localPrefixes = await _localIpv4CClassPrefixes();
    if (localPrefixes.isEmpty) {
      // 关键逻辑：若无法获取本机网段（偶发权限/系统状态异常），不应直接拒绝连接；此时放行交由连接结果判定。
      return true;
    }
    // 关键逻辑：统一以“本机当前连接网络的前三段前缀”判断同一局域网，避免跨场地误连旧缓存 IP。
    return localPrefixes.contains(prefix);
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
      DebugUtils.log(
        '拒绝连接：目标服务器不在同一局域网内，host=$host, localPrefixes=${await _localIpv4CClassPrefixes()}',
        name: 'socket',
      );
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
      final bool sameLan = await _isServerInSameLan(endpoint.ip);
      if (!sameLan) {
        // 关键逻辑：历史缓存 IP 不在当前局域网时跳过直连，避免跨场地误连旧设备。
        DebugUtils.log('跳过历史IP直连：不在同一局域网，serverType=$serverType, ip=${endpoint.ip}', name: 'socket');
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
    endpoint.connectionState.value = state;
    if (state == SocketState.connecting || state == SocketState.disconnected || state == SocketState.failed) {
      // 关键逻辑：一旦进入新一轮连接尝试（或连接失败/断开），需要重置标记，确保下次 connected 会补发一次课程列表。
      endpoint.hasRequestedCourseListInCurrentConnection = false;
      // 关键逻辑：连接状态变化时重置接收时间戳，避免前台健康检查误判为“长期无消息”。
      endpoint.lastMessageReceivedMs = 0;
    }
    if (state == SocketState.disconnected) {
      endpoint.connectedServerIp.value = null;
    }
    if (state == SocketState.connected) {
      endpoint.lastConnectedMs = DateTime.now().millisecondsSinceEpoch;
      // 关键逻辑：存在“底层自动重连成功，但未走 SocketService.connect()”的场景；
      // 此时需要在连接就绪时补发课程列表请求，否则 UI 可能一直没有本地课程清单。
      if (endpoint.connectedServerIp.value == null) {
        final cached = _loadLastServerEndpoint(serverType);
        if (cached != null) {
          endpoint.connectedServerIp.value = cached.ip;
        }
      }
      _requestCourseListOncePerConnection(serverType);
    }
    //当所有服务器连接都断开时，重置课程列表相关的 UI 状态 。
    /*if (!_clientManager.isAnyConnected) {
      isCourseListLoading.value = true;
      courseList.clear();
    }*/
  }

  void _onServerMessageReceived(ServerType serverType, MESSAGE message) {
    final endpoint = _endpoint(serverType);
    // 关键逻辑：收到任意消息（含 HeartEcho）就刷新接收时间戳，用于前台“假连接”检测。
    endpoint.lastMessageReceivedMs = DateTime.now().millisecondsSinceEpoch;
    endpoint.messageController.add(message);
    _allMessageController.add((serverType, message));
    _handleMessage(serverType, message);
  }

  UdpDiscoveryService get discoveryService => _discoveryService;

  SocketClientManager get clientManager => _clientManager;
}
