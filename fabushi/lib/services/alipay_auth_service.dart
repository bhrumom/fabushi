import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'mahayana_command_service.dart';

/// 支付宝认证服务
/// 处理支付宝登录授权相关功能
class AlipayAuthService {
  final MahayanaCommandService _mahayana = MahayanaCommandService();

  // 获取后端URL
  Future<String> get baseUrl async {
    return await AppSettings.getBackendUrl();
  }

  Map<String, dynamic> _successAuthPayload(
    Map<String, dynamic> data, {
    bool defaultOneClick = false,
  }) {
    return {
      'success': true,
      'token': data['token'],
      'username': data['username'] ?? data['user']?['username'],
      'email': data['email'] ?? data['user']?['email'],
      'user': data['user'],
      'isNewUser': data['isNewUser'] ?? false,
      'needsRegistration': data['needsRegistration'] ?? false,
      'alipayUser': data['alipayUser'],
      'message': data['message'],
      'isOneClick': data['isOneClick'] ?? defaultOneClick,
    };
  }

  /// 获取支付宝登录授权URL
  Future<Map<String, dynamic>> getAlipayLoginUrl({String? platform}) async {
    try {
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.alipay.start',
        if (platform?.trim().isNotEmpty == true) 'platform': platform!.trim(),
      });
      return {
        'success': true,
        'loginUrl': data['loginUrl'] ?? data['authUrl'],
        'state': data['state'],
        'appId': data['appId'],
        'platform': data['platform'],
      };
    } catch (error) {
      debugPrint('大乘命令层获取支付宝登录URL失败: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  /// 获取支付宝SDK授权字符串
  /// 用于移动端SDK直接调用支付宝APP
  Future<Map<String, dynamic>> getAlipayAuthString() async {
    try {
      final data = await _mahayana.execute(const {
        '@type': 'mahayana.auth.alipay.sdk.start',
      });
      return {
        'success': data['success'] ?? data['authString'] != null,
        'authString': data['authString'],
        'targetId': data['targetId'],
      };
    } catch (error) {
      debugPrint('大乘命令层获取支付宝授权字符串失败: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  /// SDK授权登录（将auth_code发送给后端换取用户信息和token）
  Future<Map<String, dynamic>> alipaySDKLogin(
    String authCode, {
    String? targetId,
  }) async {
    try {
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.alipay.sdk.complete',
        'authCode': authCode,
        if (targetId?.trim().isNotEmpty == true) 'targetId': targetId!.trim(),
      });
      if (data['needsRegistration'] == true && data['token'] == null) {
        return {
          'success': false,
          'needsRegistration': true,
          'alipayUser': data['alipayUser'],
          'message': data['message'] ?? '新用户需要注册',
        };
      }
      return _successAuthPayload(data);
    } catch (error) {
      debugPrint('大乘命令层 SDK 登录失败: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  /// 支付宝登录回调处理
  Future<Map<String, dynamic>> alipayLogin(
    String authCode,
    String? state,
  ) async {
    try {
      final data = await _mahayana.execute({
        '@type': 'mahayana.auth.alipay.complete',
        'authCode': authCode,
        if (state?.trim().isNotEmpty == true) 'state': state!.trim(),
      });
      if (data['needsRegistration'] == true && data['token'] == null) {
        return {
          'success': false,
          'needsRegistration': true,
          'alipayUser': data['alipayUser'],
          'message': data['message'] ?? '新用户需要注册',
        };
      }
      return _successAuthPayload(data);
    } catch (error) {
      debugPrint('大乘命令层支付宝登录失败: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  /// 支付宝账号注册（新用户）
  Future<Map<String, dynamic>> alipayRegister({
    required String alipayProviderSubject,
    required String username,
    required String password,
    String? alipaySubjectType,
    String? nickname,
    String? avatar,
    String? email,
  }) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'alipayProviderSubject': alipayProviderSubject,
          if (alipaySubjectType != null && alipaySubjectType.isNotEmpty)
            'alipaySubjectType': alipaySubjectType,
          'username': username,
          'password': password,
          'nickname': nickname,
          'avatar': avatar,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _successAuthPayload(data);
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '支付宝注册失败'};
      }
    } catch (e) {
      debugPrint('支付宝注册失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  /// 支付宝一键注册（自动生成用户名和邮箱）
  Future<Map<String, dynamic>> alipayOneClickRegister({
    required String alipayProviderSubject,
    String? alipaySubjectType,
    String? nickname,
    String? avatar,
  }) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/alipay/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'alipayProviderSubject': alipayProviderSubject,
          if (alipaySubjectType != null && alipaySubjectType.isNotEmpty)
            'alipaySubjectType': alipaySubjectType,
          'alipayNickname': nickname,
          'alipayAvatar': avatar,
          'oneClick': true,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _successAuthPayload(data, defaultOneClick: true);
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '支付宝一键注册失败'};
      }
    } catch (e) {
      debugPrint('支付宝一键注册失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }
}
