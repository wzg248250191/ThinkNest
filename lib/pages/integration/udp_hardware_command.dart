import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class UdpHardwareCommandResult {
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

  final String remoteIp;
  final int remotePort;
  final int localPort;
  final String command;
  final Uint8List commandBytes;
  final DateTime sentAt;
  final DateTime? receivedAt;
  final Uint8List? responseBytes;
  final String? responseText;
  final bool timedOut;
  final Object? error;

  Duration get roundTripTime {
    final receivedAt = this.receivedAt;
    if (receivedAt == null) {
      return Duration.zero;
    }
    return receivedAt.difference(sentAt);
  }

  bool get isSuccess => error == null && !timedOut;
}

class UdpHardwareCommander {
  const UdpHardwareCommander({
    this.defaultLocalPort = 10000,
    this.defaultTimeout = const Duration(seconds: 2),
    this.encoding = latin1,
    this.reuseAddress = true,
  });

  final int defaultLocalPort;
  final Duration defaultTimeout;
  final Encoding encoding;
  final bool reuseAddress;

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
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        bindPort,
        reuseAddress: reuseAddress,
      );

      socket.writeEventsEnabled = true;
      socket.readEventsEnabled = true;

      socket.send(commandBytes, remoteAddress, remotePort);

      final Datagram? response = await _receiveFirstMatch(
        socket,
        remoteAddress: remoteAddress,
        remotePort: remotePort,
        timeout: effectiveTimeout,
      );

      if (response == null) {
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

  String _decode(Uint8List bytes) {
    final Encoding encoding = this.encoding;
    if (encoding is Utf8Codec) {
      return encoding.decode(bytes, allowMalformed: true);
    }
    return encoding.decode(bytes);
  }

  Future<Datagram?> _receiveFirstMatch(
    RawDatagramSocket socket, {
    required InternetAddress remoteAddress,
    required int remotePort,
    required Duration timeout,
  }) async {
    final Completer<Datagram?> completer = Completer<Datagram?>();
    Timer? timer;
    StreamSubscription<RawSocketEvent>? subscription;

    void safeComplete(Datagram? value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    timer = Timer(timeout, () {
      safeComplete(null);
    });

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
