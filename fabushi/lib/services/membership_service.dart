import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'api_client.dart';

class MembershipService {
  final ApiRequester _apiClient;

  MembershipService({ApiRequester? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getMembershipStatus(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.stripeMembershipStatusUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (_isSuccess(response) && response['membership'] != null) {
        return {'success': true, 'membership': response['membership']};
      }

      return _failureResponse(response, '获取会员状态失败');
    } catch (e) {
      debugPrint('获取会员状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> createPaymentSession(
    String token,
    String priceType,
  ) async {
    try {
      final endpoint = Uri.parse(AppConfig.stripeCreateSubscriptionUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {'priceType': priceType},
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'paymentUrl': response['paymentUrl'],
          'sessionId': response['sessionId'],
        };
      }

      return _failureResponse(response, '创建支付会话失败');
    } catch (e) {
      debugPrint('创建支付会话失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> createAlipayOrder(
    String token,
    String plan,
  ) async {
    try {
      final endpoint = Uri.parse(AppConfig.alipayCreateOrderUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {'plan': plan},
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'qrCode': response['qrCode'],
          'orderId': response['orderId'],
          'amount': response['amount'],
          'plan': response['plan'],
          'orderString': response['orderString'],
        };
      }

      return _failureResponse(response, '创建支付宝订单失败');
    } catch (e) {
      debugPrint('创建支付宝订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> createAlipayWebOrder(
    String token,
    String plan,
  ) async {
    try {
      final response = await _apiClient.post(
        '/api/alipay/create-order',
        body: {'plan': plan, 'platform': 'web'},
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'paymentUrl': response['paymentUrl'],
          'orderId': response['orderId'],
          'amount': response['amount'],
          'plan': response['plan'],
        };
      }

      return _failureResponse(response, '创建支付宝Web订单失败');
    } catch (e) {
      debugPrint('创建支付宝Web订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> queryAlipayOrderStatus(
    String token,
    String orderId,
  ) async {
    try {
      final response = await _apiClient.get(
        Uri.parse(AppConfig.alipayQueryOrderUrl).path,
        token: token,
        queryParams: {'orderId': orderId},
      );

      if (_isSuccess(response)) {
        return response;
      }

      return _failureResponse(response, '查询订单状态失败');
    } catch (e) {
      debugPrint('查询支付宝订单状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> queryStripeSessionStatus(
    String token,
    String sessionId,
  ) async {
    try {
      final endpoint = Uri.parse(AppConfig.stripeSessionStatusUrl).path;
      final response = await _apiClient.get(
        endpoint,
        token: token,
        queryParams: {'sessionId': sessionId},
      );

      if (_isSuccess(response)) {
        return response;
      }

      return _failureResponse(response, '查询Stripe会话状态失败');
    } catch (e) {
      debugPrint('查询Stripe会话状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> redeemCode(String token, String code) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminUseRedeemCodeUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {'code': code},
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'message': response['message'] ?? '兑换成功',
          'membershipType': response['membershipType'],
          'expiresAt': response['expiresAt'],
          'daysAdded': response['daysAdded'],
        };
      }

      return _failureResponse(response, '兑换失败');
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
          'type': codeType,
          'quantity': quantity,
          'description': description,
        },
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'codes': response['codes'],
          'type': response['type'],
          'message': response['message'],
        };
      }

      return _failureResponse(response, '生成兑换码失败');
    } catch (e) {
      debugPrint('生成兑换码失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> getAdminStats(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminCheckStatusUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (_isSuccess(response)) {
        return {
          'success': true,
          'isAdmin': response['isAdmin'],
          'email': response['email'],
          'username': response['username'],
        };
      }

      return _failureResponse(response, '获取管理员状态失败');
    } catch (e) {
      debugPrint('获取管理员状态失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> getRedeemCodes(
    String token, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) {
        queryParams['status'] = status;
      }

      final endpoint = Uri.parse(AppConfig.adminRedeemCodesUrl).path;
      final response = await _apiClient.get(
        endpoint,
        token: token,
        queryParams: queryParams,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'codes': response['codes'],
          'total': response['total'],
          'page': response['page'],
          'totalPages': response['totalPages'],
        };
      }

      return _failureResponse(response, '获取兑换码列表失败');
    } catch (e) {
      debugPrint('获取兑换码列表失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> verifyAppleReceipt(
    String token,
    String transactionId,
    String productId,
  ) async {
    try {
      final endpoint = Uri.parse(AppConfig.appleVerifyReceiptUrl).path;
      final response = await _apiClient.post(
        endpoint,
        body: {'transactionId': transactionId, 'productId': productId},
        token: token,
      );

      if (_isSuccess(response)) {
        return {
          'success': true,
          'message': response['message'] ?? '会员激活成功',
          'membershipType': response['membershipType'],
          'expiresAt': response['expiresAt'],
          'alreadyProcessed': response['alreadyProcessed'] == true,
        };
      }

      return _failureResponse(response, '收据验证失败');
    } catch (e) {
      debugPrint('Apple IAP 收据验证失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> queryAlipayOrderPublic(String orderId) async {
    try {
      final endpoint = Uri.parse(AppConfig.alipayQueryOrderUrl).path;
      final response = await _apiClient.get(
        endpoint,
        queryParams: {'orderId': orderId},
      );

      if (_isSuccess(response)) {
        return {'success': true, 'order': response};
      }

      return _failureResponse(response, '查询订单失败');
    } catch (e) {
      debugPrint('查询支付宝订单失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> getPurchaseHistory(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminPurchaseHistoryUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (_isSuccess(response) && response['purchases'] != null) {
        return {'success': true, 'purchases': response['purchases']};
      }

      return _failureResponse(response, '获取购买记录失败');
    } catch (e) {
      debugPrint('获取购买记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  Future<Map<String, dynamic>> getRedeemHistory(String token) async {
    try {
      final endpoint = Uri.parse(AppConfig.adminRedeemHistoryUrl).path;
      final response = await _apiClient.get(endpoint, token: token);

      if (_isSuccess(response) && response['redeems'] != null) {
        return {'success': true, 'redeems': response['redeems']};
      }

      return _failureResponse(response, '获取兑换记录失败');
    } catch (e) {
      debugPrint('获取兑换记录失败: $e');
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  bool _isSuccess(Map<String, dynamic> response) => response['success'] == true;

  Map<String, dynamic> _failureResponse(
    Map<String, dynamic> response,
    String fallbackMessage,
  ) {
    return {
      'success': false,
      'message': _extractMessage(response, fallbackMessage),
      if (response['statusCode'] != null) 'statusCode': response['statusCode'],
      if (response['errorKey'] != null) 'errorKey': response['errorKey'],
      if (response['details'] != null) 'details': response['details'],
    };
  }

  String _extractMessage(
    Map<String, dynamic> response,
    String fallbackMessage,
  ) {
    final message = response['message'] ?? response['error'];
    return message is String && message.isNotEmpty ? message : fallbackMessage;
  }

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

  Map<String, dynamic> getTrialMembership() {
    return {
      'name': '7天试用',
      'price': '免费',
      'duration': '7天',
      'features': ['体验高级功能', '有限制的全球法布施', '基础技术支持'],
    };
  }
}
