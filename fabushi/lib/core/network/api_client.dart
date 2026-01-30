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

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}$endpoint');
      final response = await _client.get(url, headers: _headers).timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}$endpoint');
      final response = await _client
          .post(url, headers: _headers, body: jsonEncode(body))
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw AuthException('认证失败');
    } else if (response.statusCode >= 500) {
      throw ServerException('服务器错误');
    } else {
      throw AppException('请求失败: ${response.statusCode}');
    }
  }

  void dispose() {
    _client.close();
  }
}
