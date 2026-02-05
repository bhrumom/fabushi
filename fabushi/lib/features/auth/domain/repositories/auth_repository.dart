import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String username, String password);
  Future<Either<Failure, User>> register(
    String username,
    String email,
    String password,
    String verificationCode,
  );
  Future<Either<Failure, void>> sendVerificationCode(String email, String type);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User>> getCurrentUser();
  Future<Either<Failure, void>> resetPassword(String email, String code, String newPassword);
}
