import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'app_settings.dart';
import 'api_client.dart';
import 'worker_config.dart';

class MembershipService {
  // API 客户端实例
  late final ApiClient _apiClient;

  MembershipService() {
    _apiClient = ApiClient();
  }

  // 获取后端URL
  Future<String> get baseUrl async {
    return await AppSettings.getBackendUrl();
  }

  Future<Map<String, dynamic>> getMembershipStatus(String token) async {
    try {
      // 使用 /api/stripe/membership-status 端点
      final endpoint = Uri.parse(AppConfig.stripeMembershipStatusUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (response != null) {
        return {'success': true, 'membership': response};
      } else {
        return {'success': false, 'message': '获取会员状态失败'};
      }
    } catch (e) {
      debugPrint('获取会员状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> createPaymentSession(String token, String priceType) async {
    try {
      final endpoint = Uri.parse(AppConfig.stripeCreateSubscriptionUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {
          'priceType': priceType, // monthly, quarterly, yearly
        },
        token: token,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'paymentUrl': response['paymentUrl'],
          'sessionId': response['sessionId'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '创建支付会话失败'};
      }
    } catch (e) {
      debugPrint('创建支付会话失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> createAlipayOrder(String token, String plan) async {
    try {
      final endpoint = Uri.parse(AppConfig.alipayCreateOrderUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {
          'plan': plan, // monthly, quarterly, yearly
        },
        token: token,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'qrCode': response['qrCode'],
          'orderId': response['orderId'],
          'amount': response['amount'],
          'plan': response['plan'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '创建支付宝订单失败'};
      }
    } catch (e) {
      debugPrint('创建支付宝订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  /// 创建支付宝Web端订单（电脑网站支付）
  Future<Map<String, dynamic>> createAlipayWebOrder(String token, String plan) async {
    try {
      final endpoint = '/api/alipay/create-order';
      final response = await _apiClient.post(
        endpoint,
        body: {
          'plan': plan,
          'platform': 'web', // 标识为Web端支付
        },
        token: token,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'paymentUrl': response['paymentUrl'],
          'orderId': response['orderId'],
          'amount': response['amount'],
          'plan': response['plan'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '创建支付宝Web订单失败'};
      }
    } catch (e) {
      debugPrint('创建支付宝Web订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  /// 查询支付宝订单状态
  Future<Map<String, dynamic>> queryAlipayOrderStatus(String token, String orderId) async {
    try {
      final endpoint = '/api/alipay/query-order?orderId=$orderId';
      final response = await _apiClient.get(endpoint, token: token);

      if (response != null) {
        return response;
      } else {
        return {'success': false, 'message': '查询订单状态失败'};
      }
    } catch (e) {
      debugPrint('查询支付宝订单状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  /// 查询Stripe会话状态
  Future<Map<String, dynamic>> queryStripeSessionStatus(String token, String sessionId) async {
    try {
      final endpoint = Uri.parse(AppConfig.stripeSessionStatusUrl).path;
      final response = await _apiClient.get(
        endpoint,
        token: token,
        queryParams: {'sessionId': sessionId},
      );

      if (response != null) {
        return response;
      } else {
        return {'success': false, 'message': '查询Stripe会话状态失败'};
      }
    } catch (e) {
      debugPrint('查询Stripe会话状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> redeemCode(String token, String code) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminUseRedeemCodeUrl).path;
      final response = await _apiClient.post(endpoint, body: {'code': code}, token: token);

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? '兑换成功',
          'membershipType': response['membershipType'],
          'expiresAt': response['expiresAt'],
          'daysAdded': response['daysAdded'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '兑换失败'};
      }
    } catch (e) {
      debugPrint('兑换码请求失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> generateRedeemCodes(
    String token,
    String codeType,
    int quantity, {
    String description = '',
  }) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminCreateRedeemCodeUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {
          'type': codeType, // trial_7, monthly, quarterly, yearly
          'quantity': quantity,
          'description': description,
        },
        token: token,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'codes': response['codes'],
          'type': response['type'],
          'message': response['message'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '生成兑换码失败'};
      }
    } catch (e) {
      debugPrint('生成兑换码失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> getAdminStats(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminCheckStatusUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (response['success'] == true) {
        return {
          'success': true,
          'isAdmin': response['isAdmin'],
          'email': response['email'],
          'username': response['username'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '获取管理员状态失败'};
      }
    } catch (e) {
      debugPrint('获取管理员状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取兑换码列表
  Future<Map<String, dynamic>> getRedeemCodes(
    String token, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{'page': page.toString(), 'limit': limit.toString()};
      if (status != null) {
        queryParams['status'] = status;
      }

      final endpoint = Uri.parse(AppConfig.adminRedeemCodesUrl).path;
      final response = await _apiClient.get(endpoint, token: token, queryParams: queryParams);

      if (response['success'] == true) {
        return {
          'success': true,
          'codes': response['codes'],
          'total': response['total'],
          'page': response['page'],
          'totalPages': response['totalPages'],
        };
      } else {
        return {'success': false, 'message': response['message'] ?? '获取兑换码列表失败'};
      }
    } catch (e) {
      debugPrint('获取兑换码列表失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 查询支付宝订单状态（无token版本）
  Future<Map<String, dynamic>> queryAlipayOrderPublic(String orderId) async {
    try {
      final endpoint = Uri.parse(AppConfig.alipayQueryOrderUrl).path;
      final response = await _apiClient.get(endpoint, queryParams: {'orderId': orderId});

      if (response['success'] == true) {
        return {'success': true, 'order': response};
      } else {
        return {'success': false, 'message': response['message'] ?? '查询订单失败'};
      }
    } catch (e) {
      debugPrint('查询支付宝订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取购买记录
  Future<Map<String, dynamic>> getPurchaseHistory(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminPurchaseHistoryUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (response != null && response['purchases'] != null) {
        return {'success': true, 'purchases': response['purchases']};
      } else {
        return {'success': false, 'message': '获取购买记录失败'};
      }
    } catch (e) {
      debugPrint('获取购买记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取兑换记录
  Future<Map<String, dynamic>> getRedeemHistory(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminRedeemHistoryUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (response != null && response['redeems'] != null) {
        return {'success': true, 'redeems': response['redeems']};
      } else {
        return {'success': false, 'message': '获取兑换记录失败'};
      }
    } catch (e) {
      debugPrint('获取兑换记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // 获取会员价格信息
  Map<String, Map<String, dynamic>> getMembershipPrices() {
    return {
      'monthly': {
        'name': '月度会员',
        'price': '¥21.00',
        'duration': '30天',
        'features': ['基础功能访问', '每日10次使用额度', '邮件支持'],
      },
      'quarterly': {
        'name': '季度会员',
        'price': '¥63.00',
        'duration': '90天',
        'features': ['基础功能访问', '每日30次使用额度', '邮件支持', '优先客服'],
      },
      'yearly': {
        'name': '年度会员',
        'price': '¥252.00',
        'duration': '365天',
        'features': ['基础功能访问', '每日100次使用额度', '邮件支持', '优先客服', '专属功能'],
      },
    };
  }

  // 获取试用会员信息
  Map<String, dynamic> getTrialMembership() {
    return {
      'name': '7天试用',
      'price': '免费',
      'duration': '7天',
      'features': ['体验高级功能', '有限制的全球法布施', '基础技术支持'],
    };
  }
}
