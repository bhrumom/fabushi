import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

/// 统一的API客户端
class ApiClient {
  final http.Client _client;
  String? _token;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    ApiConstants.headerContentType: ApiConstants.contentTypeJson,
    ApiConstants.headerAccept: ApiConstants.contentTypeJson,
    if (_token != null) ApiConstants.headerAuthorization: 'Bearer $_token',
  };

  Future<Map<String, dynamic>> get(String endpoint) {
    return _sendRequest(() {
      final url = Uri.parse('${AppConfig.apiUrl}$endpoint');
      return _client
          .get(url, headers: _headers)
          .timeout(AppConfig.requestTimeout);
    });
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _sendRequest(() {
      final url = Uri.parse('${AppConfig.apiUrl}$endpoint');
      return _client
          .post(url, headers: _headers, body: jsonEncode(body))
          .timeout(AppConfig.requestTimeout);
    });
  }

  Future<Map<String, dynamic>> _sendRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      return _handleResponse(response);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw NetworkException('请求超时，请检查网络连接');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final parsedBody = _tryDecodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      if (parsedBody is Map<String, dynamic>) {
        return parsedBody;
      }

      throw ServerException('响应格式错误');
    }

    final message = _extractErrorMessage(parsedBody, response.statusCode);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthException(message);
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      throw ValidationException(message);
    }

    if (response.statusCode >= 500) {
      throw ServerException(message);
    }

    throw AppException(message);
  }

  dynamic _tryDecodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  String _extractErrorMessage(dynamic parsedBody, int statusCode) {
    if (parsedBody is Map<String, dynamic>) {
      for (final key in const ['message', 'error', 'detail']) {
        final value = parsedBody[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    if (parsedBody is String && parsedBody.trim().isNotEmpty) {
      return parsedBody;
    }

    return '请求失败: $statusCode';
  }

  void dispose() {
    _client.close();
  }
}
