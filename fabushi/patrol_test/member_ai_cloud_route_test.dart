import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/app_settings.dart';
import 'package:global_dharma_sharing/services/dacheng_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  patrolTest('member AI chat uses cloud quota API on desktop', ($) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.setAiBackendModeName('auto');

    final requests = <http.Request>[];
    final service = DachengAiService(
      baseUrl: () async => 'https://ai.example.test',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://ai.example.test/api/ai/chat');
        expect(request.headers['Authorization'], 'Bearer member-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['message'], '会员 AI 路由测试');
        expect(body['username'], 'member_user');
        expect(body['clientMembershipHint'], true);

        return http.Response(
          jsonEncode({
            'success': true,
            'conversationId': 'conv_member_route',
            'provider': 'deepseek',
            'model': 'deepseek-chat',
            'message': '云端 API 已接管会员额度。',
            'usage': {
              'promptTokens': 3,
              'completionTokens': 4,
              'totalTokens': 7,
              'remainingTokens': 999993,
              'monthlyLimit': 1000000,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('会员 AI 云端额度'))),
      ),
    );
    expect($('会员 AI 云端额度'), findsOneWidget);

    final result = await service.sendChat(
      message: '会员 AI 路由测试',
      token: 'member-token',
      username: 'member_user',
      isMember: true,
    );

    expect(result.provider, 'deepseek');
    expect(result.usage.monthlyLimit, 1000000);
    expect(requests, hasLength(1));
  });
}
