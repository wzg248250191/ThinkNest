import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:think_nest/pages/integration/udp_hardware_command.dart';

void main() {
  test('UdpHardwareCommander can send and receive one response', () async {
    final RawDatagramSocket server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final StreamSubscription<RawSocketEvent> sub = server.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? datagram;
      while ((datagram = server.receive()) != null) {
        final Datagram d = datagram!;
        final Uint8List data = d.data;
        final Uint8List response = Uint8List.fromList(<int>[...data, ...'|ACK'.codeUnits]);
        server.send(response, d.address, d.port);
      }
    });
    addTearDown(sub.cancel);

    final UdpHardwareCommander commander = UdpHardwareCommander(defaultTimeout: const Duration(seconds: 1));
    final result = await commander.executiveCommand(
      ip: InternetAddress.loopbackIPv4.address,
      port: server.port.toString(),
      command: 'PING',
      localPort: 0,
    );

    expect(result.isSuccess, isTrue);
    expect(result.responseText, 'PING|ACK');
    expect(result.responseBytes, isNotNull);
    expect(result.roundTripTime, isNot(Duration.zero));
  });

  test('UdpHardwareCommander times out when no response', () async {
    final RawDatagramSocket server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    final UdpHardwareCommander commander = UdpHardwareCommander(defaultTimeout: const Duration(milliseconds: 150));
    final result = await commander.executiveCommand(
      ip: InternetAddress.loopbackIPv4.address,
      port: server.port.toString(),
      command: 'PING',
      localPort: 0,
    );

    expect(result.timedOut, isTrue);
    expect(result.responseBytes, isNull);
    expect(result.responseText, isNull);
    expect(result.error, isNull);
  });
}
