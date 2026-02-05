import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String username;
  final String? email;
  final bool emailVerified;
  final String createdAt;
  final Membership membership;

  const User({
    required this.username,
    this.email,
    required this.emailVerified,
    required this.createdAt,
    required this.membership,
  });

  @override
  List<Object?> get props => [username, email, emailVerified, createdAt, membership];
}

class Membership extends Equatable {
  final String type;
  final bool isActive;
  final String? expiresAt;
  final int? daysRemaining;

  const Membership({
    required this.type,
    required this.isActive,
    this.expiresAt,
    this.daysRemaining,
  });

  bool get isTrial => type == 'trial' && isActive;
  bool get isPaid => type == 'paid' && isActive;
  bool get isExpired => !isActive || type == 'expired';

  @override
  List<Object?> get props => [type, isActive, expiresAt, daysRemaining];
}
