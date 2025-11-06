import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'app_settings.dart';

/// Cloudflare Worker 专用服务
/// 处理与 Cloudflare Worker 后端的所有交互
class CloudflareWorkerService {
  // 获取后端URL
  Future<String> get baseUrl async {
    return await AppSettings.getBackendUrl();
  }

  // 微信登录相关
  Future<Map<String, dynamic>> getWechatLoginUrl() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/auth/wechat/login-url'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'authUrl': data['authUrl'], 'state': data['state']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '获取微信登录URL失败'};
      }
    } catch (e) {
      debugPrint('获取微信登录URL失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> wechatLogin(String code, String? state) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/wechat/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'state': state}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'isNewUser': data['isNewUser'] ?? false,
          'needsRegistration': data['needsRegistration'] ?? false,
          'wechatUser': data['wechatUser'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '微信登录失败'};
      }
    } catch (e) {
      debugPrint('微信登录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> bindWechat(String openid, String email, String password) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/wechat/bind'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'openid': openid, 'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '微信绑定失败'};
      }
    } catch (e) {
      debugPrint('微信绑定失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> wechatRegister({
    required String openid,
    required String username,
    required String password,
    String? nickname,
    String? headimgurl,
    String? email,
  }) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/wechat/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'openid': openid,
          'username': username,
          'password': password,
          'nickname': nickname,
          'headimgurl': headimgurl,
          'email': email,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'username': data['username'],
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '微信注册失败'};
      }
    } catch (e) {
      debugPrint('微信注册失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> unbindWechat(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/wechat/unbind'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '微信解绑失败'};
      }
    } catch (e) {
      debugPrint('微信解绑失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取用户详细信息
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/auth/user-info'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '获取用户信息失败'};
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 绑定邮箱
  Future<Map<String, dynamic>> bindEmail(
    String token,
    String email,
    String verificationCode,
  ) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/auth/bind-email'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'verificationCode': verificationCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'], 'email': data['email']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '绑定邮箱失败'};
      }
    } catch (e) {
      debugPrint('绑定邮箱失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取购买记录
  Future<Map<String, dynamic>> getPurchaseHistory(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/admin/purchase-history'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'purchases': data['purchases'], 'total': data['total']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '获取购买记录失败'};
      }
    } catch (e) {
      debugPrint('获取购买记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取兑换记录
  Future<Map<String, dynamic>> getRedeemHistory(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/admin/redeem-history'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'redeems': data['redeems'], 'total': data['total']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '获取兑换记录失败'};
      }
    } catch (e) {
      debugPrint('获取兑换记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 删除兑换码（管理员功能）
  Future<Map<String, dynamic>> deleteRedeemCode(String token, String code) async {
    try {
      final url = await baseUrl;
      final response = await http.delete(
        Uri.parse('$url/api/admin/delete-redeem-code'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '删除兑换码失败'};
      }
    } catch (e) {
      debugPrint('删除兑换码失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取管理员价格
  Future<Map<String, dynamic>> getAdminPrice(String token, String plan) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/admin/get-price'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'plan': plan}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'isAdmin': data['isAdmin'],
          'originalPrice': data['originalPrice'],
          'adminPrice': data['adminPrice'],
          'price': data['price'],
          'plan': data['plan'],
        };
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '获取价格失败'};
      }
    } catch (e) {
      debugPrint('获取价格失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // Stripe 取消订阅
  Future<Map<String, dynamic>> cancelSubscription(String token) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/stripe/cancel-subscription'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? '取消订阅失败'};
      }
    } catch (e) {
      debugPrint('取消订阅失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }
}
