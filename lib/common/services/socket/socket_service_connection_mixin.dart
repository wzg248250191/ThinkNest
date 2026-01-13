/// SocketService 的“连接与发现”能力集合（同一 library 的 part 文件）。
///
/// 这个 mixin 负责把“网络层能力”接入到 [SocketServiceBase]：
/// - 生命周期：在 onInit 中初始化 SocketClientManager 与 UdpDiscoveryService，并注册回调
/// - UDP 扫描：scanForServers/stopServerDiscovery + 扫描复用（避免并发扫描）
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
  });

  final int id;
  final int priority;
  final String source;
  final bool autoReconnect;
  final Duration? connectTimeout;
  final Duration udpTimeout;
  bool cancelled = false;
}

mixin SocketServiceConnectionMixin on SocketServiceBase, SocketServiceSendMixin {
  final Map<ServerType, _EnsureConnectSession> _ensureConnectSessions = <ServerType, _EnsureConnectSession>{};
  int _ensureConnectSessionSeq = 0;

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

  /// 点击触发的单次连接尝试：历史 IP 直连一次，失败后 UDP 扫描一次
  ///
  /// 说明：
  /// - 用于“用户操作时若未连接，立刻提示失败，但后台做一次连接准备”的场景
  /// - 不开启自动重连，避免后台持续重连造成耗电/耗网
  /// - 关键逻辑：复用 ensureConnected 的并发去重，避免与启动/开关触发的连接并发时重复 connect
  Future<bool> connectOncePreferLastEndpointThenUdp(
    ServerType serverType, {
    Duration connectTimeout = const Duration(seconds: 2),
    Duration udpTimeout = const Duration(seconds: 2),
  }) {
    DebugUtils.log(
      '课程详情开始尝试连接|${serverType.displayName}',
      name: 'socket',
    );
    return ensureConnected(
      serverType,
      // 关键逻辑：点击触发只做一次连接尝试，不启用底层自动重连，避免后台持续重连造成耗电/耗网。
      autoReconnect: false,
      udpTimeout: udpTimeout,
      // 关键逻辑：课程详情页等交互场景需要更短的 TCP 连接超时，避免 UI 侧等待过久。
      connectTimeout: connectTimeout,
      priority: 3,
      source: 'course_detail',
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
  void stopServerDiscovery() {
    _discoveryService.stopDiscovery();
    isScanning.value = false;
    _scanServersInFlight = null;
  }

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

  /// 仅使用历史缓存的 IP/端口发起直连（不做 UDP 扫描）
  ///
  /// 说明：
  /// - 用于“业务点击触发时希望快速验证连接是否可用”的场景
  /// - 若没有历史缓存则直接返回 false
  Future<bool> connectToLastEndpoint(
    ServerType serverType, {
    bool autoReconnect = false,
    Duration? connectTimeout,
  }) async {
    final endpoint = _loadLastServerEndpoint(serverType);
    if (endpoint == null) {
      return false;
    }
    return await connect(
      serverType,
      endpoint.ip,
      endpoint.port,
      autoReconnect: autoReconnect,
      connectTimeout: connectTimeout,
    );
  }

  /// 连接到发现的服务器
  Future<bool> connectToDiscoveredServer(DiscoveredServer server) async {
    final serverType = ServerTypeExtension.fromClientEnd(server.serverType);
    return await connect(serverType, server.ipAddress, server.tcpPort);
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
    DebugUtils.log(
      'app启动开始尝试连接',
      name: 'socket',
    );

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
            source: 'startup',
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
    Duration? connectTimeout,
    Duration udpTimeout = const Duration(seconds: 3),
    Future<List<DiscoveredServer>> Function()? scanOnceOverride,
    int priority = 2,
    String source = 'unknown',
  }) {
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
      connectTimeout: connectTimeout,
      udpTimeout: udpTimeout,
    );
    _ensureConnectSessions[serverType] = session;

    final Future<bool> future = _ensureConnectedInternal(
      serverType,
      autoReconnect: autoReconnect,
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
      if (stillCurrent && ok && _clientManager.getClient(serverType).isConnected) {
        _clientManager.setAutoReconnectEnabled(serverType, session.autoReconnect);
      } else if (stillCurrent && !session.autoReconnect) {
        _clientManager.setAutoReconnectEnabled(serverType, false);
      }
      return ok;
    });
  }

  /// 在给定等待窗口内反复尝试，直到指定服务器连接就绪
  ///
  /// 说明：
  /// - 适配“PC 开机→服务自启较慢”的场景，避免业务层只尝试一次就失败
  /// - 内部会循环调用 ensureConnected（历史 IP 直连 → UDP 扫描兜底），并做指数退避等待
  /// - [maxWait] 传 null 时表示不设上限，直到连接成功或 [shouldContinue] 返回 false
  Future<bool> waitForConnected(
    ServerType serverType, {
    Duration? maxWait = const Duration(seconds: 45),
    Duration initialDelay = const Duration(seconds: 2),
    Duration maxDelay = const Duration(seconds: 15),
    Duration minUdpTimeout = const Duration(seconds: 3),
    Duration maxUdpTimeout = const Duration(seconds: 20),
    bool Function()? shouldContinue,
  }) async {
    if (_clientManager.getClient(serverType).isConnected) {
      return true;
    }

    final DateTime? deadline = maxWait == null ? null : DateTime.now().add(maxWait);
    Duration delay = initialDelay;
    int attempt = 0;

    bool continueOk() => shouldContinue?.call() ?? true;

    while (continueOk() && (deadline == null || DateTime.now().isBefore(deadline))) {
      if (_clientManager.getClient(serverType).isConnected) {
        return true;
      }

      attempt++;
      final int udpSeconds = (minUdpTimeout.inSeconds + (attempt ~/ 2) * 2)
          .clamp(minUdpTimeout.inSeconds, maxUdpTimeout.inSeconds);
      final bool ok = await ensureConnected(
        serverType,
        // 关键逻辑：waitForConnected 已由上层控制重试节奏，这里不启用底层自动重连，避免后台“自发无限重连”。
        autoReconnect: false,
        udpTimeout: Duration(seconds: udpSeconds),
        source: 'wait_for_connected',
      );
      if (ok && _clientManager.getClient(serverType).isConnected) {
        // 关键逻辑：连接成功后再开启自动重连，兼顾“等待窗口可控”和“后续断线可恢复”。
        _clientManager.setAutoReconnectEnabled(serverType, true);
        return true;
      }
      // 关键逻辑：兜底防御——确保单次尝试失败后不遗留任何自动重连定时器。
      _clientManager.setAutoReconnectEnabled(serverType, false);

      final Duration remaining =
          deadline == null ? const Duration(days: 3650) : deadline.difference(DateTime.now());
      if (deadline != null && remaining <= Duration.zero) {
        break;
      }

      final Duration sleep = delay > remaining ? remaining : delay;
      await Future.delayed(sleep);

      final int nextMs = (delay.inMilliseconds * 2)
          .clamp(initialDelay.inMilliseconds, maxDelay.inMilliseconds);
      delay = Duration(milliseconds: nextMs);
    }

    final connected = _clientManager.getClient(serverType).isConnected;
    if (!connected) {
      // 关键逻辑：等待窗口结束或被取消时，确保不遗留底层自动重连，避免后台持续消耗网络/电量。
      _clientManager.setAutoReconnectEnabled(serverType, false);
    }
    return connected;
  }

  /// ensureConnected 的内部实现
  ///
  /// 说明：
  /// - 先尝试历史 IP 直连（由 [autoReconnect] 决定是否启用底层自动重连）
  /// - 失败后进行 UDP 扫描并连接（由 [autoReconnect] 决定是否启用底层自动重连）
  Future<bool> _ensureConnectedInternal(
    ServerType serverType, {
    required bool autoReconnect,
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
    if (endpoint != null) {
      if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
        return false;
      }
      if (!await _isServerInSameLan(endpoint.ip)) {
        // 关键逻辑：历史缓存 IP 不在当前局域网时，直接跳过直连，避免跨场地误连。
        DebugUtils.log('跳过历史IP直连：不在同一局域网，serverType=$serverType, ip=${endpoint.ip}', name: 'socket');
      } else {
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

    if (_ensureConnectSessions[serverType]?.id != sessionId || (_ensureConnectSessions[serverType]?.cancelled ?? false)) {
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

  /// 自动发现并连接所有服务器
  Future<Map<ServerType, bool>> autoDiscoverAndConnectAll({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final servers = await scanForServers(timeout: timeout);

    Future<bool> connectIfFound(ServerType serverType) async {
      final discovered = _pickDiscoveredServer(servers, serverType);
      if (discovered == null) {
        return false;
      }
      // 关键逻辑：自动发现属于“单次连接尝试”，不应在失败时开启底层自动重连，避免后台持续重试造成耗电/耗网。
      final ok = await connect(
        serverType,
        discovered.ipAddress,
        discovered.tcpPort,
        autoReconnect: false,
      );
      if (ok) {
        // 关键逻辑：连接成功后再开启自动重连，用于后续断线恢复。
        _clientManager.setAutoReconnectEnabled(serverType, true);
      }
      return ok;
    }

    final results = await Future.wait<bool>([
      connectIfFound(ServerType.wall),
      connectIfFound(ServerType.desktop),
    ]);

    return {ServerType.wall: results[0], ServerType.desktop: results[1]};
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

    _discoveryService.onError = (error) {
      DebugUtils.log('UDP发现错误: $error', name: 'socket');
    };
  }

  void _onServerStateChanged(ServerType serverType, SocketState state) {
    final endpoint = _endpoint(serverType);
    endpoint.connectionState.value = state;
    if (state == SocketState.connecting || state == SocketState.disconnected || state == SocketState.failed) {
      // 关键逻辑：一旦进入新一轮连接尝试（或连接失败/断开），需要重置标记，确保下次 connected 会补发一次课程列表。
      endpoint.hasRequestedCourseListInCurrentConnection = false;
    }
    if (state == SocketState.disconnected) {
      endpoint.connectedServerIp.value = null;
    }
    if (state == SocketState.connected) {
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
    _endpoint(serverType).messageController.add(message);
    _allMessageController.add((serverType, message));
    _handleMessage(serverType, message);
  }

  UdpDiscoveryService get discoveryService => _discoveryService;

  SocketClientManager get clientManager => _clientManager;
}
