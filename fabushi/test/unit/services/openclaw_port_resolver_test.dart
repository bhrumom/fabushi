import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/openclaw/openclaw_port_resolver.dart';

void main() {
  group('OpenClawPortResolver', () {
    test('uses the requested loopback port when it is bindable', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final requestedPort = socket.port;
      await socket.close();

      final candidate = await const OpenClawPortResolver().resolve(
        requestedPort,
      );

      expect(candidate.port, requestedPort);
      expect(candidate.isFallback, isFalse);
      expect(candidate.reason, isNull);
    });

    test(
      'selects a fallback loopback port when requested port is busy',
      () async {
        final busySocket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );

        try {
          final candidate = await const OpenClawPortResolver().resolve(
            busySocket.port,
          );

          expect(candidate.port, isNot(busySocket.port));
          expect(candidate.isFallback, isTrue);
          expect(candidate.reason, contains('${busySocket.port}'));

          final verificationSocket = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            candidate.port,
          );
          await verificationSocket.close();
        } finally {
          await busySocket.close();
        }
      },
    );
  });
}
