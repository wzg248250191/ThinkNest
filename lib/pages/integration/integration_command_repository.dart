import 'dart:convert';
import 'dart:typed_data';

import 'models/device_info_config.dart';
import 'udp_hardware_command.dart';

enum IntegrationDeviceCommandType {
  open,
  close,
  query,
}

class IntegrationCommandRepository {
  IntegrationCommandRepository({UdpHardwareCommander? commander})
      : _commander = commander ?? const UdpHardwareCommander();

  final UdpHardwareCommander _commander;

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

  static Uint8List buildCommandBytes({
    required String command,
    required int commandBase,
    Encoding encoding = latin1,
  }) {
    final int base = commandBase == 2 ? 2 : 16;
    if (base == 2) {
      return _tryParseBinary(command) ?? Uint8List.fromList(encoding.encode(command));
    }
    return _tryParseHex(command) ?? Uint8List.fromList(encoding.encode(command));
  }

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

  static String _normalizeHexText(String text) {
    String s = text.trim();
    if (s.isEmpty) {
      return '';
    }
    s = s.replaceAll(RegExp(r'0x', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[^0-9a-fA-F]+'), '');
    return s.toUpperCase();
  }

  static String _bytesToUpperHex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }

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

  static Uint8List? _tryParseBinary(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return Uint8List(0);
    }

    final List<String> parts = trimmed.split(RegExp(r'[\s,;]+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      return Uint8List(0);
    }

    final List<int> bytes = <int>[];
    for (final part in parts) {
      final String p = part.trim();
      if (!RegExp(r'^[01]+$').hasMatch(p)) {
        return null;
      }
      final int value = int.parse(p, radix: 2);
      if (value < 0 || value > 255) {
        return null;
      }
      bytes.add(value);
    }
    return Uint8List.fromList(bytes);
  }

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
