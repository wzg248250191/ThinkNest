import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:think_nest/pages/integration/integration_command_repository.dart';
import 'package:think_nest/pages/integration/udp_hardware_command.dart';

void main() {
  test('buildCommandBytes parses hex string', () {
    final bytes = IntegrationCommandRepository.buildCommandBytes(
      command: '01 0A ff',
      commandBase: 16,
    );
    expect(bytes, <int>[0x01, 0x0A, 0xFF]);
  });

  test('buildCommandBytes parses odd-length hex string', () {
    final bytes = IntegrationCommandRepository.buildCommandBytes(
      command: 'A',
      commandBase: 16,
    );
    expect(bytes, <int>[0x0A]);
  });

  test('buildCommandBytes parses binary tokens', () {
    final bytes = IntegrationCommandRepository.buildCommandBytes(
      command: '00000001 00000010 11111111',
      commandBase: 2,
    );
    expect(bytes, <int>[1, 2, 255]);
  });

  test('buildCommandBytes falls back to text on invalid input', () {
    final bytes = IntegrationCommandRepository.buildCommandBytes(
      command: 'ZZ',
      commandBase: 16,
    );
    expect(bytes, isNotEmpty);
  });

  test('parseSwitchIsOn parses from responseBytes hex signature', () {
    final onResult = UdpHardwareCommandResult(
      remoteIp: '127.0.0.1',
      remotePort: 1,
      localPort: 1,
      command: '',
      commandBytes: Uint8List(0),
      sentAt: DateTime(2025),
      receivedAt: DateTime(2025),
      responseBytes: Uint8List.fromList(<int>[0x7E, 0x31, 0x0D]),
      responseText: null,
      timedOut: false,
      error: null,
    );
    expect(IntegrationCommandRepository.parseSwitchIsOn(onResult), true);

    final offResult = UdpHardwareCommandResult(
      remoteIp: '127.0.0.1',
      remotePort: 1,
      localPort: 1,
      command: '',
      commandBytes: Uint8List(0),
      sentAt: DateTime(2025),
      receivedAt: DateTime(2025),
      responseBytes: Uint8List.fromList(<int>[0x7E, 0x30, 0x0D]),
      responseText: null,
      timedOut: false,
      error: null,
    );
    expect(IntegrationCommandRepository.parseSwitchIsOn(offResult), false);
  });

  test('parseSwitchIsOn parses from responseText hex signature', () {
    final result = UdpHardwareCommandResult(
      remoteIp: '127.0.0.1',
      remotePort: 1,
      localPort: 1,
      command: '',
      commandBytes: Uint8List(0),
      sentAt: DateTime(2025),
      receivedAt: DateTime(2025),
      responseBytes: null,
      responseText: '7E31',
      timedOut: false,
      error: null,
    );
    expect(IntegrationCommandRepository.parseSwitchIsOn(result), true);
  });

  test('parseSwitchIsOn keeps ON/OFF parsing fallback', () {
    final result = UdpHardwareCommandResult(
      remoteIp: '127.0.0.1',
      remotePort: 1,
      localPort: 1,
      command: '',
      commandBytes: Uint8List(0),
      sentAt: DateTime(2025),
      receivedAt: DateTime(2025),
      responseBytes: null,
      responseText: 'ON',
      timedOut: false,
      error: null,
    );
    expect(IntegrationCommandRepository.parseSwitchIsOn(result), true);
  });
}
