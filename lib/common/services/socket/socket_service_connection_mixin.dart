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

mixin SocketServiceConnectionMixin on SocketServiceBase, SocketServiceSendMixin {
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
  Future<bool> connect(ServerType serverType, String host, int port, {bool autoReconnect = true}) async {
    final success =
        await _clientManager.connect(serverType, host, port, autoReconnect: autoReconnect);
    if (success) {
      _endpoint(serverType).connectedServerIp.value = host;
      unawaited(_persistLastServerEndpoint(serverType, host, port));
      requestCourseList(serverType);
    }
    return success;
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
  /// - 策略：
  ///   1) 有历史 IP：循环直连多次（适配网络未就绪）
  ///   2) 无历史 IP：做一次短 UDP 扫描找到服务器并连接
  Future<Map<ServerType, bool>> recoverConnectionsAtStartup({
    int attempts = 5,
    Duration retryDelay = const Duration(seconds: 2),
    Duration udpTimeout = const Duration(seconds: 2),
  }) async {
    final wallEndpoint = _loadLastServerEndpoint(ServerType.wall);
    final desktopEndpoint = _loadLastServerEndpoint(ServerType.desktop);

    Future<List<DiscoveredServer>>? scanFuture;
    if (wallEndpoint == null || desktopEndpoint == null) {
      scanFuture = _scanForServersOnce(timeout: udpTimeout);
    }

    Future<bool> recoverOne(ServerType serverType, ({String ip, int port})? endpoint) async {
      if (_clientManager.getClient(serverType).isConnected) {
        return true;
      }

      if (endpoint == null) {
        final servers = await scanFuture!;
        final discovered = _pickDiscoveredServer(servers, serverType);
        if (discovered == null) {
          return false;
        }
        return await connect(
          serverType,
          discovered.ipAddress,
          discovered.tcpPort,
          autoReconnect: true,
        );
      }

      for (var i = 0; i < attempts; i++) {
        final ok = await connect(
          serverType,
          endpoint.ip,
          endpoint.port,
          autoReconnect: false,
        );
        if (ok) {
          _clientManager.setAutoReconnectEnabled(serverType, true);
          return true;
        }
        if (i < attempts - 1) {
          await Future.delayed(retryDelay);
        }
      }
      return false;
    }

    final results = await Future.wait<bool>([
      recoverOne(ServerType.wall, wallEndpoint),
      recoverOne(ServerType.desktop, desktopEndpoint),
    ]);

    return {ServerType.wall: results[0], ServerType.desktop: results[1]};
  }

  /// 业务强关联：确保指定类型服务器已连接（历史 IP 优先，必要时 UDP 扫描兜底）
  ///
  /// 说明：
  /// - 用于“用户点击打开设备/课程”等动作触发
  /// - 内部做了并发去重：同一类型同时触发只会跑一次
  Future<bool> ensureConnected(
    ServerType serverType, {
    Duration udpTimeout = const Duration(seconds: 3),
  }) {
    final inFlight = _ensureConnectInFlight[serverType];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _ensureConnectedInternal(serverType, udpTimeout: udpTimeout)
        .whenComplete(() => _ensureConnectInFlight.remove(serverType));
    _ensureConnectInFlight[serverType] = future;
    return future;
  }

  /// ensureConnected 的内部实现
  ///
  /// 说明：
  /// - 先尝试历史 IP 直连（autoReconnect=true）
  /// - 失败后进行 UDP 扫描并连接（autoReconnect=true）
  Future<bool> _ensureConnectedInternal(
    ServerType serverType, {
    required Duration udpTimeout,
  }) async {
    if (_clientManager.getClient(serverType).isConnected) {
      return true;
    }

    final endpoint = _loadLastServerEndpoint(serverType);
    if (endpoint != null) {
      final ok = await connect(
        serverType,
        endpoint.ip,
        endpoint.port,
        autoReconnect: true,
      );
      if (ok) {
        return true;
      }
    }

    // 兜底：UDP 扫描获取服务器 IP
    final servers = await _scanForServersOnce(timeout: udpTimeout);
    final discovered = _pickDiscoveredServer(servers, serverType);
    if (discovered == null) {
      return false;
    }
    return await connect(serverType, discovered.ipAddress, discovered.tcpPort, autoReconnect: true);
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
    DebugUtils.log('开始自动发现服务器...', name: 'socket');
    final servers = await scanForServers(timeout: timeout);

    Future<bool> connectIfFound(ServerType serverType) async {
      final discovered = _pickDiscoveredServer(servers, serverType);
      if (discovered == null) {
        DebugUtils.log('未找到${serverType == ServerType.wall ? "墙面" : "桌面"}服务器', name: 'socket');
        return false;
      }
      final ok = await connectToDiscoveredServer(discovered);
      DebugUtils.log('${serverType == ServerType.wall ? "墙面" : "桌面"}服务器连接${ok ? "成功" : "失败"}', name: 'socket');
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
        DebugUtils.log(
          '发现${server.serverType == CLIENTEND.WALL ? "墙面" : "桌面"}服务器: ${server.ipAddress}',
          name: 'socket',
        );
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
    if (state == SocketState.disconnected) {
      endpoint.connectedServerIp.value = null;
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
