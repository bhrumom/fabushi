/// 自定义异常类
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String? message]) : super(message ?? '网络连接失败');
}

class ServerException extends AppException {
  ServerException([String? message]) : super(message ?? '服务器错误');
}

class AuthException extends AppException {
  AuthException([String? message]) : super(message ?? '认证失败');
}

class ValidationException extends AppException {
  ValidationException([String? message]) : super(message ?? '数据验证失败');
}

class CacheException extends AppException {
  CacheException([String? message]) : super(message ?? '缓存错误');
}
