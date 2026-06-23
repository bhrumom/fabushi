import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'openclaw_ai_bridge.dart';

Future<void> maybeRunOpenClawHomeChatE2E() async {
  if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  if (Platform.environment['DACHENG_E2E_OPENCLAW_CHAT'] != '1') return;

  final resultDir = Platform.environment['DACHENG_E2E_OPENCLAW_RESULT_DIR'];
  if (resultDir == null || resultDir.trim().isEmpty) return;

  unawaited(_runOpenClawHomeChatE2E(resultDir.trim()));
}

Future<void> _runOpenClawHomeChatE2E(String resultDir) async {
  final output = File(
    '$resultDir${Platform.pathSeparator}openclaw-home-chat-result.json',
  );
  await output.parent.create(recursive: true);
  final prompt = Platform.environment['DACHENG_E2E_OPENCLAW_PROMPT']?.trim();
  final message = prompt == null || prompt.isEmpty ? '请用一句话回复：南无阿弥陀佛' : prompt;
  final bridge = OpenClawAiBridge();

  try {
    final chunks = <String>[];
    var conversationId = '';
    await for (final event
        in bridge
            .sendChatStream(message: message, username: 'github-actions-e2e')
            .timeout(const Duration(seconds: 150))) {
      if (event.conversationId != null) {
        conversationId = event.conversationId!;
      }
      if (event.isDelta && event.text.trim().isNotEmpty) {
        chunks.add(event.text);
      }
      if (event.isError) {
        throw StateError(event.text);
      }
    }

    final response = chunks.join().trim();
    if (response.isEmpty) {
      throw StateError('OpenClaw returned an empty response');
    }

    await output.writeAsString(
      jsonEncode({
        'ok': true,
        'conversationId': conversationId,
        'responsePreview': response.length > 240
            ? response.substring(0, 240)
            : response,
      }),
      flush: true,
    );
  } catch (error, stackTrace) {
    await output.writeAsString(
      jsonEncode({
        'ok': false,
        'error': error.toString(),
        'stack': stackTrace.toString().split('\n').take(20).join('\n'),
      }),
      flush: true,
    );
  }
}
