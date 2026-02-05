import 'package:equatable/equatable.dart';

/// 失败基类
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = '网络连接失败']) : super(message);
}

class ServerFailure extends Failure {
  const ServerFailure([String message = '服务器错误']) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure([String message = '认证失败']) : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure([String message = '数据验证失败']) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = '缓存错误']) : super(message);
}
