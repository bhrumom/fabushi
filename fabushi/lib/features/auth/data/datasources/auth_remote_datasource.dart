import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String username, String password);
  Future<UserModel> register(
    String username,
    String email,
    String password,
    String verificationCode,
  );
  Future<void> sendVerificationCode(String email, String type);
  Future<void> logout();
  Future<UserModel> getCurrentUser();
  Future<void> resetPassword(String email, String code, String newPassword);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<UserModel> login(String username, String password) async {
    final response = await apiClient.post(ApiConstants.login, {
      'username': username,
      'password': password,
    });

    if (response['token'] != null) {
      apiClient.setToken(response['token']);
    }

    return UserModel.fromJson(response['user']);
  }

  @override
  Future<UserModel> register(
    String username,
    String email,
    String password,
    String verificationCode,
  ) async {
    final response = await apiClient.post(ApiConstants.register, {
      'username': username,
      'email': email,
      'password': password,
      'verificationCode': verificationCode,
    });

    if (response['token'] != null) {
      apiClient.setToken(response['token']);
    }

    return UserModel.fromJson(response['user']);
  }

  @override
  Future<void> sendVerificationCode(String email, String type) async {
    await apiClient.post(ApiConstants.sendVerificationCode, {'email': email, 'type': type});
  }

  @override
  Future<void> logout() async {
    await apiClient.post(ApiConstants.logout, {});
    apiClient.setToken(null);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await apiClient.get(ApiConstants.userInfo);
    return UserModel.fromJson(response['user']);
  }

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async {
    await apiClient.post(ApiConstants.resetPassword, {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }
}
