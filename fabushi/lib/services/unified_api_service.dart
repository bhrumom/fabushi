import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_service.dart';
import 'mahayana_sdk.dart';

/// Compatibility facade for callers that still expect `http.Response`.
/// All production requests are executed by the embedded Mahayana Rust client.
class UnifiedApiService {
  static final UnifiedApiService _instance = UnifiedApiService._internal();
  factory UnifiedApiService() => _instance;
  UnifiedApiService._internal();

  void initialize() {}
  void dispose() {}

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    bool authenticated = false,
  }) => HttpService.get(
    endpoint,
    queryParams: queryParams,
    useAuth: authenticated,
  );

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool authenticated = false,
  }) {
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    return HttpService.post(uri.toString(), body: body, useAuth: authenticated);
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool authenticated = false,
  }) {
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    return HttpService.put(uri.toString(), body: body, useAuth: authenticated);
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    bool authenticated = false,
  }) {
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    return HttpService.delete(uri.toString(), useAuth: authenticated);
  }

  Future<Map<String, dynamic>> login(String email, String password) =>
      MahayanaSdk.instance.execute({
        '@type': 'mahayana.auth.password.login',
        'username': email,
        'password': password,
      });

  Future<Map<String, dynamic>> register(String email, String password) =>
      MahayanaSdk.instance.execute({
        '@type': 'mahayana.auth.register',
        'username': email.split('@').first,
        'email': email,
        'password': password,
        'verificationCode': '',
      });

  Future<Map<String, dynamic>> getUserInfo(String ignoredToken) async =>
      _handleResponse(await get('/api/auth/user-info', authenticated: true));

  Future<Map<String, dynamic>> checkMembershipStatus(
    String ignoredToken,
  ) async => _handleResponse(
    await get('/api/stripe/membership-status', authenticated: true),
  );

  Future<Map<String, dynamic>> createAlipayOrder(
    String ignoredToken,
    Map<String, dynamic> orderData,
  ) async => _handleResponse(
    await post(
      '/api/alipay/create-order',
      body: orderData,
      authenticated: true,
    ),
  );

  Future<Map<String, dynamic>> checkAdminStatus(String ignoredToken) async =>
      _handleResponse(
        await get('/api/admin/check-status', authenticated: true),
      );

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
      };
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : {'success': false, 'error': '响应格式错误'};
  }
}
