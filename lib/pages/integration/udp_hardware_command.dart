import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// UDP 硬件指令执行结果
///
/// 说明：
/// - 记录一次 UDP 指令交互的关键数据：远端信息、发送内容、响应内容、耗时、异常/超时等
/// - 用于上层做日志展示、错误提示、以及状态解析（例如开关 ON/OFF）
class UdpHardwareCommandResult {
  /// 创建一次 UDP 指令交互的结果对象
  const UdpHardwareCommandResult({
    required this.remoteIp,
    required this.remotePort,
    required this.localPort,
    required this.command,
    required this.commandBytes,
    required this.sentAt,
    required this.receivedAt,
    required this.responseBytes,
    required this.responseText,
    required this.timedOut,
    required this.error,
  });

  /// 远端 IP
  final String remoteIp;

  /// 远端端口
  final int remotePort;

  /// 本地绑定端口（用于发送/接收）
  final int localPort;

  /// 原始命令文本（便于日志与调试）
  final String command;

  /// 实际发送的字节（可能是文本编码，也可能是 hex/bin 解析后的字节）
  final Uint8List commandBytes;

  /// 发送时间
  final DateTime sentAt;

  /// 接收时间（未收到则为 null）
  final DateTime? receivedAt;

  /// 响应字节（未收到则为 null）
  final Uint8List? responseBytes;

  /// 响应文本（由 [UdpHardwareCommander.encoding] 解码，未收到则为 null）
  final String? responseText;

  /// 是否超时（超时属于一种“无响应”的失败形态）
  final bool timedOut;

  /// 异常对象（发生异常时非空）
  final Object? error;

  /// 往返耗时
  ///
  /// 说明：
  /// - 未收到响应时返回 Duration.zero
  Duration get roundTripTime {
    final receivedAt = this.receivedAt;
    if (receivedAt == null) {
      return Duration.zero;
    }
    return receivedAt.difference(sentAt);
  }

  /// 本次指令是否成功
  ///
  /// 规则：
  /// - 既没有异常，也没有超时，才认为成功
  bool get isSuccess => error == null && !timedOut;
}

/// UDP 硬件命令执行器
///
/// 说明：
/// - 通过 UDP 向指定 IP/端口发送指令，并在超时窗口内等待首个匹配的回包
/// - 只接收来源地址与端口都匹配的响应，避免误收同网段其他设备的 UDP 广播/回包
class UdpHardwareCommander {
  /// 创建 UDP 指令执行器
  ///
  /// 参数说明：
  /// - [defaultLocalPort] 默认本地绑定端口（可被单次调用覆盖）
  /// - [defaultTimeout] 默认等待响应超时时间（可被单次调用覆盖）
  /// - [encoding] 用于 command->bytes 与 response bytes->text 的编码规则
  /// - [reuseAddress] 是否允许端口复用（避免多实例占用导致 bind 失败）
  const UdpHardwareCommander({
    this.defaultLocalPort = 10000,
    this.defaultTimeout = const Duration(seconds: 2),
    this.encoding = latin1,
    this.reuseAddress = true,
  });

  /// 默认本地绑定端口
  final int defaultLocalPort;

  /// 默认超时时间
  final Duration defaultTimeout;

  /// 文本编码规则
  final Encoding encoding;

  /// 是否复用端口
  final bool reuseAddress;

  /// 执行一次“文本命令”的 UDP 交互
  ///
  /// 说明：
  /// - 内部会按 [encoding] 将 [command] 编码为字节，并复用 [executiveCommandBytes] 发送
  Future<UdpHardwareCommandResult> executiveCommand({
    required String ip,
    required String port,
    required String command,
    int? localPort,
    Duration? timeout,
  }) async {
    final Uint8List commandBytes = Uint8List.fromList(encoding.encode(command));
    return executiveCommandBytes(
      ip: ip,
      port: port,
      command: command,
      commandBytes: commandBytes,
      localPort: localPort,
      timeout: timeout,
    );
  }

  /// 执行一次“字节命令”的 UDP 交互
  ///
  /// 说明：
  /// - [localPort] 若不传，则使用 [defaultLocalPort]
  /// - [timeout] 若不传，则使用 [defaultTimeout]
  /// - 绑定 socket 后发送数据，并等待首个匹配远端的回包
  Future<UdpHardwareCommandResult> executiveCommandBytes({
    required String ip,
    required String port,
    required String command,
    required Uint8List commandBytes,
    int? localPort,
    Duration? timeout,
  }) async {
    final int remotePort = int.parse(port);
    final InternetAddress remoteAddress = InternetAddress(ip);
    final int bindPort = localPort ?? defaultLocalPort;
    final Duration effectiveTimeout = timeout ?? defaultTimeout;
    final DateTime sentAt = DateTime.now();

    RawDatagramSocket? socket;
    try {
      /// 绑定本地 UDP 端口，用于发送与接收
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        bindPort,
        reuseAddress: reuseAddress,
      );

      socket.writeEventsEnabled = true;
      socket.readEventsEnabled = true;

      /// 发送指令字节到远端
      socket.send(commandBytes, remoteAddress, remotePort);

      /// 等待来自指定远端的首个回包（超时则返回 null）
      final Datagram? response = await _receiveFirstMatch(
        socket,
        remoteAddress: remoteAddress,
        remotePort: remotePort,
        timeout: effectiveTimeout,
      );

      if (response == null) {
        /// 超时：未收到回包
        return UdpHardwareCommandResult(
          remoteIp: ip,
          remotePort: remotePort,
          localPort: bindPort,
          command: command,
          commandBytes: commandBytes,
          sentAt: sentAt,
          receivedAt: null,
          responseBytes: null,
          responseText: null,
          timedOut: true,
          error: null,
        );
      }

      final Uint8List bytes = response.data;
      final String text = _decode(bytes);
      final DateTime receivedAt = DateTime.now();
      /// 成功：收到回包并完成解码
      return UdpHardwareCommandResult(
        remoteIp: ip,
        remotePort: remotePort,
        localPort: bindPort,
        command: command,
        commandBytes: commandBytes,
        sentAt: sentAt,
        receivedAt: receivedAt,
        responseBytes: bytes,
        responseText: text,
        timedOut: false,
        error: null,
      );
    } catch (e) {
      /// 异常：socket bind/send/receive 等任一环节抛错
      return UdpHardwareCommandResult(
        remoteIp: ip,
        remotePort: remotePort,
        localPort: bindPort,
        command: command,
        commandBytes: commandBytes,
        sentAt: sentAt,
        receivedAt: null,
        responseBytes: null,
        responseText: null,
        timedOut: false,
        error: e,
      );
    } finally {
      socket?.close();
    }
  }

  /// 将响应字节按当前编码解码为字符串
  ///
  /// 说明：
  /// - UTF-8 允许畸形字节，避免因设备返回非标准 UTF-8 而抛错
  String _decode(Uint8List bytes) {
    final Encoding encoding = this.encoding;
    if (encoding is Utf8Codec) {
      return encoding.decode(bytes, allowMalformed: true);
    }
    return encoding.decode(bytes);
  }

  /// 接收首个“来源匹配”的 UDP 回包
  ///
  /// 说明：
  /// - 只接受同时满足远端 IP 与端口匹配的 Datagram
  /// - 超时、socket 关闭、或监听错误都会返回 null
  Future<Datagram?> _receiveFirstMatch(
    RawDatagramSocket socket, {
    required InternetAddress remoteAddress,
    required int remotePort,
    required Duration timeout,
  }) async {
    final Completer<Datagram?> completer = Completer<Datagram?>();
    Timer? timer;
    StreamSubscription<RawSocketEvent>? subscription;

    /// 安全结束等待流程（确保只 complete 一次）
    void safeComplete(Datagram? value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    /// 超时计时器：到期仍未匹配到回包则返回 null
    timer = Timer(timeout, () {
      safeComplete(null);
    });

    /// 监听 socket 读事件，循环读取缓冲区中的 Datagram
    subscription = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          final Datagram d = datagram!;
          if (d.address.address == remoteAddress.address && d.port == remotePort) {
            safeComplete(d);
            return;
          }
        }
      },
      onError: (Object e) {
        safeComplete(null);
      },
      onDone: () {
        safeComplete(null);
      },
    );

    final Datagram? result = await completer.future;
    timer.cancel();
    await subscription.cancel();
    return result;
  }
}
