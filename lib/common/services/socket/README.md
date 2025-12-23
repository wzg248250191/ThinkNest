# Socket 通信模块

本模块提供与PC服务器的完整Socket通信功能，支持**同时连接两个PC服务器**：
- **墙面服务器 (WALL)**: 控制墙面显示的Unity应用
- **桌面服务器 (Desktop)**: 控制桌面显示的Unity应用

两个PC服务器之间不进行通信，都由本程序（Android/iPad端）分别控制。

## 架构说明

```
                                    ┌─────────────────┐
                                    │   墙面Unity      │
                                    │   (游戏)         │
                                    │   Port: 8100    │
                                    └────────▲────────┘
                                             │
┌─────────────────┐          ┌───────────────┴───────────────┐
│   Android/iPad  │◄────────►│   墙面PC Server (WALL)        │
│   (本项目)       │   TCP    │   TCP: 8000  UDP: 7000        │
│                 │          └───────────────────────────────┘
│                 │
│                 │          ┌───────────────────────────────┐
│                 │◄────────►│   桌面PC Server (Desktop)     │
│                 │   TCP    │   TCP: 8000  UDP: 7000        │
└─────────────────┘          └───────────────┬───────────────┘
                                             │
                                    ┌────────▼────────┐
                                    │   桌面Unity      │
                                    │   (游戏)         │
                                    │   Port: 8100    │
                                    └─────────────────┘
```

## 项目内 Socket 通信流程（按调用链）

### 1. 服务初始化（GetX 注册 → 回调绑定）

- 服务注册入口：`lib/global.dart:7` → `Global.init()`
  - `Get.put(SocketService(), permanent: true)`：注册并常驻 `SocketService`
  - `Global._autoConnectServers()`：应用启动后自动发现并连接（可按需关闭/改为手动）
- 服务初始化：`lib/common/services/socket/socket_service.dart:75` → `SocketService.onInit()`
  - `SocketService._initClientManager()`：创建 `SocketClientManager` 并绑定连接状态/消息回调
  - `SocketService._initDiscoveryService()`：创建 `UdpDiscoveryService` 并绑定发现回调

### 2. 发现服务器（UDP 广播 → 收包解析 → 回调上报）

- 触发扫描：
  - `lib/global.dart:31` → `Global._autoConnectServers()` 调用 `SocketService.autoDiscoverAndConnectAll()`
  - 或手动调用：`lib/common/services/socket/socket_service.dart:172` → `SocketService.scanForServers()`
- 扫描实现：`lib/common/services/socket/udp_discovery_service.dart:88` → `UdpDiscoveryService.startDiscovery()`
  - 创建 UDP Socket：`RawDatagramSocket.bind(...)` 并开启广播
  - 发送发现包（多次重试）：`_sendDiscoveryRequestsWithRetry()` → `_sendDiscoveryRequest()`（广播到 `255.255.255.255:7000` 并尝试常见网段）
  - 接收响应：`_socket.listen(_onDataReceived)` → `_processResponse(datagram)`
  - 上报发现结果：`onServerDiscovered?.call(server)`（该回调在 `SocketService._initDiscoveryService()` 中注册）
  - 提前结束优化：`_tryCompleteDiscoveryEarly()`（同时发现 `WALL` 与 `Desktop` 后结束扫描，不再继续发/等待）

### 3. 建立连接（选定服务器 → TCP connect → 状态回调）

- 自动连接：`lib/common/services/socket/socket_service.dart:222` → `SocketService.autoDiscoverAndConnectAll()`
  - 通过 `servers.where(...).firstOrNull` 找到墙面/桌面服务器
  - 调用 `SocketService.connectToDiscoveredServer(server)`
- 连接链路：
  - `lib/common/services/socket/socket_service.dart:190` → `SocketService.connect(serverType, host, port)`
  - `lib/common/services/socket/socket_client_manager.dart:158` → `SocketClientManager.connect(serverType, host, port)`
  - `lib/common/services/socket/socket_client.dart:84` → `SocketClient.connect(host, port)` → `_doConnect()`
  - `_doConnect()` 内部通过 `Socket.connect(...)` 建立 TCP 长连接，并注册 `_socket.listen(_onDataReceived, ...)`

### 4. 发送消息（业务构建 protobuf → 封包 → 写入 TCP）

- 业务侧常用入口（对外 API）：`lib/common/services/socket/socket_service.dart`
  - `sendToServer(serverType, serverMessage)`：封装为 `MSGTYPE.ServerRequest`
  - `sendToUnity(serverType, unityMessage)`：封装为 `MSGTYPE.UnityRequest`
  - 便捷方法：`setVolume(...)` / `controlApplication(...)` / `sendUnityOperation(...)` / `sendUnityData(...)`
- 发送链路：
  - `SocketService.sendToServer(...)` / `SocketService.sendToUnity(...)`
  - `lib/common/services/socket/socket_client_manager.dart:218` → `SocketClientManager.sendTo(serverType, message)`
  - `lib/common/services/socket/socket_client.dart:149` → `SocketClient.sendMessage(message)`
  - `lib/common/services/socket/message_parser.dart:180` → `MessageParser.encodeMessage(message)`（封包：13字节头 + protobuf body）
  - `SocketClient._processSendBuffer()` → `_socket.add(bytes)` + `_socket.flush()`

### 5. 接收消息（TCP 收包 → 解决粘包 → 反序列化 → 上层分发）

- TCP 收包入口：`lib/common/services/socket/socket_client.dart:264` → `SocketClient._onDataReceived(data)`
  - 将数据追加到 `_receiveBuffer`
  - `SocketClient._processReceiveBuffer()` 循环拆包（解决粘包/半包）
  - 头解析：`lib/common/services/socket/message_parser.dart:61` → `MessageParser.unParseHead(...)`
  - 完整包解析：`MessageParser.unParse(...)` → `MESSAGE.fromBuffer(...)`
  - 回调上抛：`SocketClient.onMessageReceived?.call(message)`
- 上层回调分发：
  - `lib/common/services/socket/socket_client_manager.dart:91` / `:102` 将消息转发给 `SocketClientManager.onWallMessageReceived/onDesktopMessageReceived`
  - `lib/common/services/socket/socket_service.dart:117` → `SocketService._onServerMessageReceived(serverType, message)`
    - 写入流：`wallMessageStream` / `desktopMessageStream` / `allMessageStream`
    - 内部处理：`SocketService._handleMessage(...)`（目前主要是日志/状态弹窗）

### 6. 心跳与重连（保持连接可用）

- 心跳：`lib/common/services/socket/socket_client.dart:383` → `SocketClient._startHeartbeat()` → `_sendHeartbeat()`（定时发送 `MSGTYPE.HeartEcho`）
- 重连：`SocketClient._handleDisconnect()` → `_scheduleReconnect()`（非主动断开时按策略尝试重连）

## 文件结构

```
lib/common/services/socket/
├── index.dart                    # 导出文件
├── socket_client.dart            # Socket客户端核心
├── socket_client_manager.dart    # 多客户端管理器
├── socket_service.dart           # GetX Service封装
├── udp_discovery_service.dart    # UDP服务器发现服务
├── example_usage.dart            # 使用示例
├── message_constants.dart        # 消息常量定义（内部使用）
├── message_parser.dart           # 消息解析器（内部使用）
└── README.md                     # 说明文档
```

## 快速开始

### 1. 初始化服务

在 `main.dart` 或初始化代码中注册服务：

```dart
import 'package:get/get.dart';
import 'package:think_nest/common/services/socket/index.dart';

void main() {
  // 注册Socket服务
  Get.put(SocketService());
  
  runApp(MyApp());
}
```

### 2. 自动发现并连接所有服务器

```dart
final socketService = Get.find<SocketService>();

// 自动发现并连接局域网内的所有服务器
final results = await socketService.autoDiscoverAndConnectAll();

print('墙面服务器: ${results[ServerType.wall]! ? "已连接" : "未连接"}');
print('桌面服务器: ${results[ServerType.desktop]! ? "已连接" : "未连接"}');
```

### 3. 手动扫描和连接服务器

```dart
final socketService = Get.find<SocketService>();

// 扫描局域网内的服务器
final servers = await socketService.scanForServers();

// 获取墙面服务器列表
final wallServers = socketService.discoveredWallServers;

// 获取桌面服务器列表  
final desktopServers = socketService.discoveredDesktopServers;

// 连接到发现的服务器
for (final server in servers) {
  await socketService.connectToDiscoveredServer(server);
}
```

### 4. 手动连接（已知IP地址）

```dart
// 连接到墙面服务器
await socketService.connectToWallServer('192.168.1.100');

// 连接到桌面服务器
await socketService.connectToDesktopServer('192.168.1.101');
```

## 发送消息

### 发送给墙面服务器

```dart
// 控制墙面音量
socketService.setWallVolume(50);

// 打开墙面应用程序
socketService.controlApplication(ServerType.wall, 'MyGame', true);

// 发送Unity操作
socketService.sendUnityOperation(ServerType.wall, 'StartGame');

// 发送Unity数据
socketService.sendUnityData(ServerType.wall, unityData);
```

### 发送给桌面服务器

```dart
// 控制桌面音量
socketService.setDesktopVolume(50);

// 打开桌面应用程序
socketService.controlApplication(ServerType.desktop, 'MyGame', true);

// 发送Unity操作
socketService.sendUnityOperation(ServerType.desktop, 'StartGame');

// 发送Unity数据
socketService.sendUnityData(ServerType.desktop, unityData);
```

### 发送给所有已连接的服务器

```dart
final serverMessage = ServerMessage()
  ..serverBehaviour = SERVERBEHAVIOUR.Volume
  ..volumeValue = 50;

socketService.sendToAllServers(serverMessage);
```

## 接收消息

### 分别监听各服务器消息

```dart
// 监听墙面服务器消息
socketService.wallMessageStream.listen((message) {
  print('墙面服务器消息: ${message.mSGtype}');
});

// 监听桌面服务器消息
socketService.desktopMessageStream.listen((message) {
  print('桌面服务器消息: ${message.mSGtype}');
});
```

### 统一监听所有消息

```dart
// 监听所有服务器消息（包含来源信息）
socketService.allMessageStream.listen((record) {
  final (serverType, message) = record;
  print('${serverType.displayName}消息: ${message.mSGtype}');
});
```

### 使用GetX响应式

```dart
// 监听墙面服务器连接状态
ever(socketService.wallConnectionState, (state) {
  print('墙面服务器: $state');
});

// 监听桌面服务器连接状态
ever(socketService.desktopConnectionState, (state) {
  print('桌面服务器: $state');
});

// 监听发现的服务器列表
ever(socketService.discoveredServers, (servers) {
  print('发现 ${servers.length} 个服务器');
});
```

## 服务器类型

### ServerType 枚举

| 类型 | 说明 | 对应CLIENTEND |
|------|------|--------------|
| `ServerType.wall` | 墙面服务器 | `CLIENTEND.WALL` |
| `ServerType.desktop` | 桌面服务器 | `CLIENTEND.Desktop` |

### 便捷扩展方法

```dart
// 获取显示名称
ServerType.wall.displayName  // "墙面服务器"

// 转换为CLIENTEND
ServerType.wall.toClientEnd()  // CLIENTEND.WALL

// 从CLIENTEND转换
ServerTypeExtension.fromClientEnd(CLIENTEND.WALL)  // ServerType.wall
```

## 连接状态

### SocketState 枚举

| 状态 | 说明 |
|------|------|
| `SocketState.disconnected` | 未连接 |
| `SocketState.connecting` | 连接中 |
| `SocketState.connected` | 已连接 |
| `SocketState.failed` | 连接失败 |

### 状态检查

```dart
// 墙面服务器是否已连接
socketService.isWallConnected

// 桌面服务器是否已连接
socketService.isDesktopConnected

// 是否有任一服务器连接
socketService.isAnyConnected

// 是否两个服务器都已连接
socketService.isAllConnected
```

## 消息类型说明

### MSGTYPE 枚举

| 类型 | 说明 |
|------|------|
| `ServerRequest` | 发送给PC服务器处理的请求 |
| `UnityRequest` | 发送给Unity的请求（通过PC服务器转发） |
| `ServerResponse` | PC服务器的响应 |
| `UnityResponse` | Unity的响应（通过PC服务器转发） |
| `HeartEcho` | 心跳消息 |
| `Status` | 状态消息 |

### OperationStatus 枚举

| 状态 | 说明 |
|------|------|
| `NullUnityClient` | Unity客户端未连接 |
| `NulliPadClient` | iPad客户端未连接 |
| `NullCourse` | 课程不存在 |
| `CoursePlayisRunning` | 课程正在运行中 |
| `DataformatterError` | 数据格式错误 |
| `DataTransferError` | 数据传输错误 |

## 服务器发现（UDP Echo）

UDP发现服务会自动区分墙面服务器和桌面服务器：

```dart
// 扫描服务器
await socketService.scanForServers();

// 获取墙面服务器列表
final wallServers = socketService.discoveredWallServers;

// 获取桌面服务器列表
final desktopServers = socketService.discoveredDesktopServers;
```

### DiscoveredServer 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `ipAddress` | String | 服务器IP地址 |
| `tcpPort` | int | TCP端口（默认8000） |
| `serverType` | CLIENTEND | 服务器类型（WALL/Desktop） |
| `discoveredAt` | DateTime | 发现时间 |

## 完整使用示例

```dart
class MyController extends GetxController {
  final socketService = Get.find<SocketService>();
  
  @override
  void onInit() {
    super.onInit();
    _setupListeners();
  }
  
  void _setupListeners() {
    // 监听连接状态
    ever(socketService.wallConnectionState, (state) {
      if (state == SocketState.connected) {
        print('墙面服务器已连接');
      }
    });
    
    ever(socketService.desktopConnectionState, (state) {
      if (state == SocketState.connected) {
        print('桌面服务器已连接');
      }
    });
    
    // 监听消息
    socketService.allMessageStream.listen((record) {
      final (serverType, message) = record;
      _handleMessage(serverType, message);
    });
  }
  
  void _handleMessage(ServerType serverType, MESSAGE message) {
    switch (message.mSGtype) {
      case MSGTYPE.UnityResponse:
        print('${serverType.displayName} Unity响应: ${message.unityMessage.operation}');
        break;
      // ... 其他处理
    }
  }
  
  // 连接服务器
  Future<void> connect() async {
    await socketService.autoDiscoverAndConnectAll();
  }
  
  // 控制墙面
  void startWallGame() {
    socketService.sendUnityOperation(ServerType.wall, 'StartGame');
  }
  
  // 控制桌面
  void startDesktopGame() {
    socketService.sendUnityOperation(ServerType.desktop, 'StartGame');
  }
  
  @override
  void onClose() {
    socketService.disconnectAll();
    super.onClose();
  }
}
```

## 消息协议

### 消息头格式（13字节）

| 字段 | 类型 | 字节数 | 说明 |
|------|------|--------|------|
| Header | short | 2 | 魔术头 0x2425 |
| Length | int | 4 | 消息体长度 |
| Version | byte | 1 | 版本号 |
| Cmd | short | 2 | 命令码 |
| Serial | int | 4 | 序列号 |

## 特性

- ✅ TCP长连接通信
- ✅ **同时支持两个服务器连接**
- ✅ Protobuf消息序列化
- ✅ 自动重连机制
- ✅ 心跳保活
- ✅ UDP服务器发现（自动区分墙面/桌面）
- ✅ 粘包处理
- ✅ GetX响应式状态管理
- ✅ 消息队列缓冲

## 注意事项

1. **网络权限**: 确保在 `AndroidManifest.xml` 中添加网络权限：
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
   ```

2. **UDP广播**: UDP发现需要设备在同一局域网内，且路由器允许广播。

3. **防火墙**: 确保PC服务器的防火墙允许端口 8000 (TCP) 和 7000 (UDP)。

4. **服务器区分**: 服务器通过 `CLIENTEND` 枚举标识自己是墙面(WALL)还是桌面(Desktop)服务器。

5. **独立控制**: 两个PC服务器之间不进行通信，各自独立运行。
