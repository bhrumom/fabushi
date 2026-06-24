import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/ai_backend_policy.dart';
import 'package:global_dharma_sharing/services/app_settings.dart';
import 'package:global_dharma_sharing/services/dacheng_ai_service.dart';
import 'package:global_dharma_sharing/services/openclaw/openclaw_ai_bridge.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  patrolTest('member AI chat uses local OpenClaw on desktop', ($) async {
    SharedPreferences.setMockInitialValues({});
    AiBackendPolicy.debugIsDesktopNativeOverride = true;
    addTearDown(() => AiBackendPolicy.debugIsDesktopNativeOverride = null);
    await AppSettings.setAiBackendModeName('auto');

    var cloudRequestCount = 0;
    final openClawBridge = _RecordingOpenClawBridge();
    final service = DachengAiService(
      baseUrl: () async => 'https://ai.example.test',
      httpClient: MockClient((request) async {
        cloudRequestCount++;
        fail('member desktop AI should use local OpenClaw, not ${request.url}');
      }),
      openClawBridge: openClawBridge,
    );

    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('会员 AI 本机 OpenClaw'))),
      ),
    );
    expect($('会员 AI 本机 OpenClaw'), findsOneWidget);

    final result = await service.sendChat(
      message: '会员 AI 路由测试',
      token: 'member-token',
      username: 'member_user',
      isMember: true,
    );

    expect(openClawBridge.callCount, 1);
    expect(openClawBridge.lastMessage, '会员 AI 路由测试');
    expect(openClawBridge.lastToken, 'member-token');
    expect(openClawBridge.lastUsername, 'member_user');
    expect(openClawBridge.lastIsMember, isTrue);
    expect(result.provider, 'openclaw-local');
    expect(result.model, 'deepseek/deepseek-chat');
    expect(cloudRequestCount, 0);
  });
}

class _RecordingOpenClawBridge extends OpenClawAiBridge {
  int callCount = 0;
  String? lastMessage;
  String? lastModel;
  Map<String, dynamic>? lastClient;
  String? lastToken;
  String? lastUsername;
  bool? lastIsMember;

  @override
  Future<DachengAiChatResult> sendChat({
    required String message,
    String? conversationId,
    String? model,
    Map<String, dynamic>? client,
    String? token,
    String? username,
    bool isMember = false,
  }) async {
    callCount++;
    lastMessage = message;
    lastModel = model;
    lastClient = client;
    lastToken = token;
    lastUsername = username;
    lastIsMember = isMember;
    return const DachengAiChatResult(
      conversationId: 'conv_member_local_openclaw',
      message: '本机 OpenClaw 已接管会员请求。',
      provider: 'openclaw-local',
      model: 'deepseek/deepseek-chat',
      usage: DachengAiUsage(
        promptTokens: 0,
        completionTokens: 0,
        totalTokens: 0,
        remainingTokens: 0,
        monthlyLimit: 0,
      ),
    );
  }
}
