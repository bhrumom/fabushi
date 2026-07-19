import 'package:flutter/foundation.dart';

import 'mahayana_sdk.dart';

/// Flutter compatibility facade over the Mahayana Rust platform client.
///
/// The String token parameters remain temporarily for source compatibility,
/// but are deliberately ignored: Flutter never receives or attaches account
/// credentials. Rust owns login state, refresh rotation, and HTTP headers.
class CloudflareWorkerService {
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await MahayanaSdk.instance.platformRequest(
        method: method,
        path: path,
        body: body,
        authenticated: authenticated,
      );
      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      if (response['ok'] == true) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['error'] ?? data['message'] ?? '请求失败',
        'statusCode': response['statusCode'],
      };
    } catch (error) {
      debugPrint('大乘 Rust 平台请求失败: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  Future<Map<String, dynamic>> getWechatLoginUrl() async {
    final data = await _request(
      'GET',
      '/api/auth/wechat/login-url',
      authenticated: false,
    );
    return {...data, 'authUrl': data['authUrl'], 'state': data['state']};
  }

  Future<Map<String, dynamic>> wechatLogin(String code, String? state) async =>
      _removedWechatCredentialFlow();

  Future<Map<String, dynamic>> bindWechat(
    String openid,
    String email,
    String password,
  ) async => _removedWechatCredentialFlow();

  Future<Map<String, dynamic>> wechatRegister({
    required String openid,
    required String username,
    required String password,
    String? nickname,
    String? headimgurl,
    String? email,
  }) async => _removedWechatCredentialFlow();

  Map<String, dynamic> _removedWechatCredentialFlow() => const {
    'success': false,
    'message': '旧微信 token 登录已移除；请等待 Rust 微信委托登录上线',
  };

  Future<Map<String, dynamic>> unbindWechat(String ignoredToken) =>
      _request('POST', '/api/auth/wechat/unbind', body: const {});

  Future<Map<String, dynamic>> getUserInfo(String ignoredToken) async {
    final data = await _request('GET', '/api/auth/user-info');
    return {'success': data['success'], 'user': data};
  }

  Future<Map<String, dynamic>> bindEmail(
    String ignoredToken,
    String email,
    String verificationCode,
  ) => _request(
    'POST',
    '/api/auth/bind-email',
    body: {'email': email, 'verificationCode': verificationCode},
  );

  Future<Map<String, dynamic>> getPurchaseHistory(String ignoredToken) =>
      _request('GET', '/api/admin/purchase-history');

  Future<Map<String, dynamic>> getRedeemHistory(String ignoredToken) =>
      _request('GET', '/api/admin/redeem-history');

  Future<Map<String, dynamic>> deleteRedeemCode(
    String ignoredToken,
    String code,
  ) =>
      _request('DELETE', '/api/admin/delete-redeem-code', body: {'code': code});

  Future<Map<String, dynamic>> getAdminPrice(
    String ignoredToken,
    String plan,
  ) => _request('POST', '/api/admin/get-price', body: {'plan': plan});

  Future<Map<String, dynamic>> cancelSubscription(String ignoredToken) =>
      _request('POST', '/api/stripe/cancel-subscription', body: const {});

  Future<Map<String, dynamic>> syncMeditationRecord(
    String ignoredToken,
    Map<String, dynamic> recordData,
  ) => _request('POST', '/api/meditation/record', body: recordData);
}
