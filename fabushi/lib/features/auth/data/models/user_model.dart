import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.username,
    super.email,
    required super.emailVerified,
    required super.createdAt,
    required super.membership,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] as String,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      membership: MembershipModel.fromJson(json['membership'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'emailVerified': emailVerified,
      'createdAt': createdAt,
      'membership': (membership as MembershipModel).toJson(),
    };
  }
}

class MembershipModel extends Membership {
  const MembershipModel({
    required super.type,
    required super.isActive,
    super.expiresAt,
    super.daysRemaining,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      type: json['type'] as String? ?? 'expired',
      isActive: json['isActive'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String?,
      daysRemaining: json['daysRemaining'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'isActive': isActive,
      'expiresAt': expiresAt,
      'daysRemaining': daysRemaining,
    };
  }
}
