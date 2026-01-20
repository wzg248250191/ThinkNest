# Socket 通信模块

本模块用于 App 与两台 PC Server（墙面/桌面）通信：TCP 端口 `8000`，UDP 发现端口 `7000`。两台 PC 互不通信，由 App 分别连接与控制。

## 文件说明（lib/common/services/socket）

- `index.dart`：对外导出入口，聚合本目录常用类型与服务。
- `server_type.dart`：`ServerType`（wall/desktop）及与 `CLIENTEND` 的映射扩展。
- `discovered_server.dart`：UDP 发现结果模型（IP、端口、服务器类型、发现时间等）。
- `socket_service.dart`：GetX Service 外观层；持有两个 `SocketClient`，提供连接状态/消息流与对外 API。
- `socket_service_connection_mixin.dart`：连接编排与恢复策略（历史 IP、UDP 兜底、并发去重、优先级、节流、同网段校验等）。
- `socket_service_send_mixin.dart`：发送侧封装（把业务对象封装成 `MESSAGE` 并交给底层发送）。
- `socket_service_handle_mixin.dart`：接收侧分发（按 `MSGTYPE` 将消息路由到对应处理）。
- `socket_client_manager.dart`：多客户端管理器（分别管理墙面/桌面 `SocketClient`，对上层统一回调）。
- `socket_client.dart`：单链接 TCP 客户端（连接、收发、粘包拆包、心跳、断线处理、自动重连定时器）。
- `udp_discovery_service.dart`：UDP 发现（广播 `discover`，收包解析出服务器类型与 IP；支持提前结束与同网段过滤）。
- `message_parser.dart`：消息封包/解包（消息头 + protobuf body），提供粘包拆包所需的解析能力。
- `message_constants.dart`：消息头常量、超时/长度等内部常量。

## 需要重连的场景与策略

### 1) App 启动后恢复连接

- 触发：启动初始化后执行恢复流程。
- 策略（位于 `socket_service_connection_mixin.dart`）：
  - 优先使用“历史 IP/端口”直连；必要时短时 UDP 扫描兜底。
  - 限定重试次数与延迟，避免启动阶段无限等待。
  - 启动阶段默认不启用底层自动重连；当某条链路确认连接成功后，再开启该链路自动重连。
  - 启动恢复阶段最多触发一次 UDP 扫描，其余尝试复用扫描结果，避免广播风暴。

### 2) 前台唤醒 / 健康检查触发的轻量恢复

- 触发：App 从后台回到前台、或检测到“疑似假连接/长时间无消息”等。
- 策略（位于 `socket_service_connection_mixin.dart`）：
  - 采用节流（throttle）限制触发频率。
  - 默认不做 UDP 扫描兜底，仅尝试 `reconnect` 与有限次“历史 IP 直连”，降低后台广播与耗电。
  - 在判断可能存在“假连接”时，可先强制断开再恢复，避免 reconnect 被假连接短路。

### 3) 用户点击触发的即时连接（例如课程详情）

- 触发：用户进入课程详情等强交互页面，需要立刻可用的连接。
- 策略（位于 `socket_service_connection_mixin.dart`）：
  - 已连接则直接返回，避免重复触发与刷日志。
  - 仅做一次快速尝试（优先 reconnect，其次历史 IP 直连有限次），失败快速返回；通常不做 UDP 扫描兜底以避免阻塞交互。

### 4) 一体化开关触发的“等待窗口”连接

- 触发：墙面/桌面开关被打开后，允许服务端稍后启动再连接。
- 策略（位于一体化开关控制器逻辑 + `ensureConnected`）：
  - 在固定等待窗口内循环重试（例如 5 分钟），超时或用户关闭开关即停止。
  - 重试默认关闭底层自动重连，由上层等待窗口统一控制节奏，避免后台长期重连与刷屏。
  - UDP 兜底扫描做节流：大多数重试只走 reconnect/历史 IP，按间隔才允许一次 UDP 兜底，避免服务器未开时持续广播导致服务端刷屏。

### 5) 断线后的持续保持（底层自动重连）

- 触发：TCP 非主动断开（网络波动、服务器重启等）。
- 策略（位于 `socket_client.dart`，由上层按场景开启/关闭）：
  - 定时心跳保活（`MSGTYPE.HeartEcho`）。
  - 在允许的场景下启用自动重连定时器；在“启动恢复/等待窗口/轻量恢复”等场景下，上层会显式关闭自动重连，防止后台无限重试。
