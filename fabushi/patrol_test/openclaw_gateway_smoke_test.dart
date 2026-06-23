import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/openclaw/openclaw_runtime.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('embedded OpenClaw Gateway starts and serves models', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('OpenClaw Patrol smoke'))),
      ),
    );
    expect($('OpenClaw Patrol smoke'), findsOneWidget);

    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return;
    }

    final target = await OpenClawRuntime.instance.ensureStarted(
      username: 'patrol-openclaw-smoke',
    );
    final response = await http
        .get(
          target.baseUri.resolve('/v1/models'),
          headers: {'Authorization': 'Bearer ${target.token}'},
        )
        .timeout(const Duration(seconds: 10));

    expect(response.statusCode, inInclusiveRange(200, 299));
    final decoded = jsonDecode(response.body);
    expect(_looksLikeModelsPayload(decoded), isTrue);

    await OpenClawRuntime.instance.stop();
  });
}

bool _looksLikeModelsPayload(Object? payload) {
  if (payload is List) return true;
  if (payload is! Map) return false;
  return payload['data'] is List ||
      payload['models'] is List ||
      payload['object'] == 'list';
}
