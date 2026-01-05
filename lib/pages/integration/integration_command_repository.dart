import 'dart:convert';
import 'dart:typed_data';

import 'models/device_info_config.dart';
import 'udp_hardware_command.dart';

/// 集成设备支持的基础命令类型
///
/// 说明：
/// - [open] 打开设备
/// - [close] 关闭设备
/// - [query] 查询设备状态（通常用于解析开关是否开启）
enum IntegrationDeviceCommandType {
  open,
  close,
  query,
}

/// 集成命令存储库
///
/// 说明：
/// - 对上层提供统一的 open/close/query/execute API
/// - 对下层通过 UDP 发送指令，并返回本次通信的结果（见 [UdpHardwareCommandResult]）
/// - 内置常用的“构建命令字节”和“解析开关是否开启”工具方法，便于复用
class IntegrationCommandRepository {
  /// 创建命令仓库
  ///
  /// 说明：
  /// - 支持注入自定义 [UdpHardwareCommander]，便于测试或替换底层实现
  IntegrationCommandRepository({UdpHardwareCommander? commander})
      : _commander = commander ?? const UdpHardwareCommander();

  /// UDP 指令执行器
  final UdpHardwareCommander _commander;

  /// 发送“打开设备”命令
  Future<UdpHardwareCommandResult> openDevice(
    DeviceInfoConfig config, {
    int? localPort,
    Duration? timeout,
  }) {
    return executeDeviceCommand(
      config,
      type: IntegrationDeviceCommandType.open,
      localPort: localPort,
      timeout: timeout,
    );
  }

  /// 发送“关闭设备”命令
  Future<UdpHardwareCommandResult> closeDevice(
    DeviceInfoConfig config, {
    int? localPort,
    Duration? timeout,
  }) {
    return executeDeviceCommand(
      config,
      type: IntegrationDeviceCommandType.close,
      localPort: localPort,
      timeout: timeout,
    );
  }

  /// 发送“查询设备状态”命令
  Future<UdpHardwareCommandResult> queryDevice(
    DeviceInfoConfig config, {
    int? localPort,
    Duration? timeout,
  }) {
    return executeDeviceCommand(
      config,
      type: IntegrationDeviceCommandType.query,
      localPort: localPort,
      timeout: timeout,
    );
  }

  /// 执行一次设备命令（打开/关闭/查询）
  ///
  /// 说明：
  /// - 会校验设备是否启用，以及 IP/端口/命令文本是否合法
  /// - 根据 [type] 从配置中选择对应命令，并将其编码为字节后通过 UDP 发送
  /// - 返回完整的 UDP 执行结果，供上层展示或进一步解析
  Future<UdpHardwareCommandResult> executeDeviceCommand(
    DeviceInfoConfig config, {
    required IntegrationDeviceCommandType type,
    int? localPort,
    Duration? timeout,
  }) async {
    if (!config.enabled) {
      return _errorResult(
        ip: config.ip,
        port: config.port,
        command: '',
        commandBytes: Uint8List(0),
        error: StateError('device disabled'),
      );
    }
    if (config.ip.trim().isEmpty || config.port.trim().isEmpty) {
      return _errorResult(
        ip: config.ip,
        port: config.port,
        command: '',
        commandBytes: Uint8List(0),
        error: StateError('invalid ip/port'),
      );
    }

    final String command = _commandTextByType(config, type);
    if (command.trim().isEmpty) {
      return _errorResult(
        ip: config.ip,
        port: config.port,
        command: command,
        commandBytes: Uint8List(0),
        error: StateError('empty command'),
      );
    }

    /// 将命令文本转换为实际要发送的字节
    ///
    /// 说明：
    /// - [config.commandBase] 决定以“字符字节”或“十六进制字节”发送命令：
    ///   - `2`：按字符编码直接转为字节数组发送（与 Unity 的 byte[] 行为对齐）
    ///   - 其他：优先按十六进制字符串解析为字节数组，失败则回退为字符编码
    final Uint8List bytes = buildCommandBytes(
      command: command,
      commandBase: config.commandBase,
    );

    return _commander.executiveCommandBytes(
      ip: config.ip,
      port: config.port,
      command: command,
      commandBytes: bytes,
      localPort: localPort,
      timeout: timeout,
    );
  }

  /// 构建 UDP 指令的字节数据
  ///
  /// 说明：
  /// - 当 [commandBase] 为 2 时：按字符编码直接转为字节数组
  /// - 否则：尝试按十六进制解析（支持 0x 前缀与多种分隔符），失败则按字符编码转字节数组
  static Uint8List buildCommandBytes({
    required String command,
    required int commandBase,
    Encoding encoding = latin1,
  }) {
    if (commandBase == 2) {
      return Uint8List.fromList(encoding.encode(command));
    }
    return _tryParseHex(command) ?? Uint8List.fromList(encoding.encode(command));
  }

  /// 从一次 UDP 结果中解析“开关是否开启”
  ///
  /// 返回：
  /// - `true/false`：解析成功得到开/关
  /// - `null`：结果失败或无法解析
  ///
  /// 说明：
  /// - 优先解析字节流（更稳定），其次解析十六进制文本，最后退回到普通文本解析
  static bool? parseSwitchIsOn(UdpHardwareCommandResult result) {
    if (!result.isSuccess) {
      return null;
    }
    final Uint8List? bytes = result.responseBytes;
    final bool? byBytes = _parseSwitchIsOnBytes(bytes);
    if (byBytes != null) {
      return byBytes;
    }

    final String text = result.responseText ?? '';
    final bool? byHexText = _parseSwitchIsOnHexText(text);
    if (byHexText != null) {
      return byHexText;
    }

    if (text.isEmpty) {
      return null;
    }
    return parseSwitchIsOnText(text);
  }

  /// 通过返回的原始字节解析开关状态
  ///
  /// 说明：
  /// - 将字节转大写 HEX 后，按协议关键字判断：
  ///   - 包含 `7E31` 认为是 ON
  ///   - 包含 `7E30` 认为是 OFF
  static bool? _parseSwitchIsOnBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final String hex = _bytesToUpperHex(bytes);
    if (hex.contains('7E31')) {
      return true;
    }
    if (hex.contains('7E30')) {
      return false;
    }
    return null;
  }

  /// 通过十六进制文本解析开关状态
  ///
  /// 说明：
  /// - 会先做规范化（去掉 0x 前缀、去除非 hex 字符、转大写）
  /// - 按协议关键字判断：
  ///   - 包含 `7E31` 认为是 ON
  ///   - 包含 `7E30` 认为是 OFF
  static bool? _parseSwitchIsOnHexText(String text) {
    final String s = _normalizeHexText(text);
    if (s.isEmpty) {
      return null;
    }
    if (s.contains('7E31')) {
      return true;
    }
    if (s.contains('7E30')) {
      return false;
    }
    return null;
  }

  /// 规范化十六进制文本（用于稳定解析）
  ///
  /// 规则：
  /// - 去掉 `0x` 前缀
  /// - 移除所有非 0-9A-F 字符
  /// - 转为大写
  static String _normalizeHexText(String text) {
    String s = text.trim();
    if (s.isEmpty) {
      return '';
    }
    s = s.replaceAll(RegExp(r'0x', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[^0-9a-fA-F]+'), '');
    return s.toUpperCase();
  }

  /// 将字节数组转为大写十六进制字符串（无分隔符）
  static String _bytesToUpperHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }

  /// 从普通文本中解析开关状态
  ///
  /// 说明：
  /// - 优先识别 ON/OFF 字样
  /// - 其次尝试匹配独立的 2 位 01/00 token（避免误判长数字串）
  static bool? parseSwitchIsOnText(String text) {
    final String s = text.replaceAll(RegExp(r'[\u0000-\u001F]'), ' ').trim();
    if (s.isEmpty) {
      return null;
    }
    final String up = s.toUpperCase();
    if (up.contains('ON')) {
      return true;
    }
    if (up.contains('OFF')) {
      return false;
    }
    final RegExp token = RegExp(r'(^|[^0-9A-Z])([01]{2})(?=$|[^0-9A-Z])', caseSensitive: false);
    final Iterable<RegExpMatch> matches = token.allMatches(up);
    if (matches.isEmpty) {
      return null;
    }
    final String last = matches.last.group(2) ?? '';
    if (last == '01') {
      return true;
    }
    if (last == '00') {
      return false;
    }
    return null;
  }

  /// 尝试按“十六进制字符串”解析命令文本
  ///
  /// 说明：
  /// - 支持 `0x` 前缀、空格/逗号/分号/下划线/冒号/短横线等分隔符
  /// - 若长度为奇数，会自动在前面补 `0`
  static Uint8List? _tryParseHex(String raw) {
    String s = raw.trim();
    if (s.isEmpty) {
      return Uint8List(0);
    }

    s = s.replaceAll(RegExp(r'0x', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[\s,;:_-]+'), '');

    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) {
      return null;
    }

    if (s.length.isOdd) {
      s = '0$s';
    }

    final List<int> bytes = <int>[];
    for (int i = 0; i < s.length; i += 2) {
      final String part = s.substring(i, i + 2);
      bytes.add(int.parse(part, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// 根据命令类型获取配置中的命令文本
  String _commandTextByType(DeviceInfoConfig config, IntegrationDeviceCommandType type) {
    switch (type) {
      case IntegrationDeviceCommandType.open:
        return config.openCmd;
      case IntegrationDeviceCommandType.close:
        return config.closeCmd;
      case IntegrationDeviceCommandType.query:
        return config.queryCmd;
    }
  }

  /// 构造一个失败的 UDP 结果（用于本地校验失败等场景）
  UdpHardwareCommandResult _errorResult({
    required String ip,
    required String port,
    required String command,
    required Uint8List commandBytes,
    required Object error,
  }) {
    final int remotePort = int.tryParse(port) ?? 0;
    return UdpHardwareCommandResult(
      remoteIp: ip,
      remotePort: remotePort,
      localPort: 0,
      command: command,
      commandBytes: commandBytes,
      sentAt: DateTime.now(),
      receivedAt: null,
      responseBytes: null,
      responseText: null,
      timedOut: false,
      error: error,
    );
  }
}
