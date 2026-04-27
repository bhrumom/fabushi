// 用户数据模型
// 定义用户相关的数据结构

class UserModel {
  final String username;
  final String? email;
  final bool emailVerified;
  final String createdAt;
  final String? wechatOpenid;
  final String? wechatNickname;
  final String? wechatHeadimgurl;
  final String? wechatBoundAt;
  final String? alipayUserId;
  final String? alipayNickname;
  final String? alipayAvatar;
  final String? alipayBoundAt;
  final String? nickname;
  final String? avatar;
  final String? phoneNumber;
  final Map<String, dynamic>? mainPractice;
  final MembershipInfo membership;

  UserModel({
    required this.username,
    this.email,
    required this.emailVerified,
    required this.createdAt,
    this.wechatOpenid,
    this.wechatNickname,
    this.wechatHeadimgurl,
    this.wechatBoundAt,
    this.alipayUserId,
    this.alipayNickname,
    this.alipayAvatar,
    this.alipayBoundAt,
    this.nickname,
    this.avatar,
    this.phoneNumber,
    this.mainPractice,
    required this.membership,
  });

  // 从JSON创建用户对象
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] as String,
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      wechatOpenid: json['wechatOpenid'] as String?,
      wechatNickname: json['wechatNickname'] as String?,
      wechatHeadimgurl: json['wechatHeadimgurl'] as String?,
      wechatBoundAt: json['wechatBoundAt'] as String?,
      alipayUserId: json['alipayUserId'] as String?,
      alipayNickname: json['alipayNickname'] as String?,
      alipayAvatar: json['alipayAvatar'] as String?,
      alipayBoundAt: json['alipayBoundAt'] as String?,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      mainPractice: json['mainPractice'] is Map
          ? Map<String, dynamic>.from(json['mainPractice'] as Map)
          : null,
      membership: MembershipInfo.fromJson(json['membership'] ?? {}),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'emailVerified': emailVerified,
      'createdAt': createdAt,
      'wechatOpenid': wechatOpenid,
      'wechatNickname': wechatNickname,
      'wechatHeadimgurl': wechatHeadimgurl,
      'wechatBoundAt': wechatBoundAt,
      'alipayUserId': alipayUserId,
      'alipayNickname': alipayNickname,
      'alipayAvatar': alipayAvatar,
      'alipayBoundAt': alipayBoundAt,
      'nickname': nickname,
      'avatar': avatar,
      'phoneNumber': phoneNumber,
      'mainPractice': mainPractice,
      'membership': membership.toJson(),
    };
  }

  // 复制并修改部分字段
  UserModel copyWith({
    String? username,
    String? email,
    bool? emailVerified,
    String? createdAt,
    String? wechatOpenid,
    String? wechatNickname,
    String? wechatHeadimgurl,
    String? wechatBoundAt,
    String? alipayUserId,
    String? alipayNickname,
    String? alipayAvatar,
    String? alipayBoundAt,
    MembershipInfo? membership,
  }) {
    return UserModel(
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      wechatOpenid: wechatOpenid ?? this.wechatOpenid,
      wechatNickname: wechatNickname ?? this.wechatNickname,
      wechatHeadimgurl: wechatHeadimgurl ?? this.wechatHeadimgurl,
      wechatBoundAt: wechatBoundAt ?? this.wechatBoundAt,
      alipayUserId: alipayUserId ?? this.alipayUserId,
      alipayNickname: alipayNickname ?? this.alipayNickname,
      alipayAvatar: alipayAvatar ?? this.alipayAvatar,
      alipayBoundAt: alipayBoundAt ?? this.alipayBoundAt,
      membership: membership ?? this.membership,
    );
  }

  // 检查是否绑定了微信
  bool get hasWechatBinding => wechatOpenid != null;

  // 获取显示名称
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    if (wechatNickname != null && wechatNickname!.isNotEmpty) {
      return wechatNickname!;
    }
    if (alipayNickname != null && alipayNickname!.isNotEmpty) {
      return alipayNickname!;
    }
    return username;
  }

  // 获取头像URL
  String? get avatarUrl {
    if (avatar != null && avatar!.isNotEmpty) {
      return avatar;
    }
    if (wechatHeadimgurl != null && wechatHeadimgurl!.isNotEmpty) {
      return wechatHeadimgurl;
    }
    if (alipayAvatar != null && alipayAvatar!.isNotEmpty) {
      return alipayAvatar;
    }
    return null;
  }

  @override
  String toString() {
    return 'UserModel(username: $username, email: $email, membership: ${membership.type})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;
}

// 会员信息模型
class MembershipInfo {
  final String type; // 'trial', 'paid', 'expired'
  final bool isActive;
  final String? expiresAt;
  final int? daysRemaining;
  final String? subscriptionId;
  final String? paymentMethod;

  MembershipInfo({
    required this.type,
    required this.isActive,
    this.expiresAt,
    this.daysRemaining,
    this.subscriptionId,
    this.paymentMethod,
  });

  factory MembershipInfo.fromJson(Map<String, dynamic> json) {
    return MembershipInfo(
      type: json['type'] as String? ?? 'expired',
      isActive: json['isActive'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String?,
      daysRemaining: json['daysRemaining'] as int?,
      subscriptionId: json['subscriptionId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'isActive': isActive,
      'expiresAt': expiresAt,
      'daysRemaining': daysRemaining,
      'subscriptionId': subscriptionId,
      'paymentMethod': paymentMethod,
    };
  }

  // 获取会员类型显示名称
  String get displayName {
    switch (type) {
      case 'trial':
        return '试用会员';
      case 'paid':
        return '付费会员';
      case 'expired':
        return '已过期';
      default:
        return '未知';
    }
  }

  // 获取会员状态颜色
  String get statusColor {
    if (isActive) {
      return type == 'trial' ? '#FFA500' : '#4CAF50'; // 橙色试用，绿色付费
    } else {
      return '#F44336'; // 红色过期
    }
  }

  // 检查是否为试用会员
  bool get isTrial => type == 'trial' && isActive;

  // 检查是否为付费会员
  bool get isPaid => type == 'paid' && isActive;

  // 检查是否已过期
  bool get isExpired => !isActive || type == 'expired';

  @override
  String toString() {
    return 'MembershipInfo(type: $type, isActive: $isActive, expiresAt: $expiresAt)';
  }
}

// 购买记录模型
class PurchaseRecord {
  final String id;
  final String orderId;
  final String plan;
  final String amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String purchasedAt;
  final String validFrom;
  final String validTo;

  PurchaseRecord({
    required this.id,
    required this.orderId,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.purchasedAt,
    required this.validFrom,
    required this.validTo,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      id: (json['id'] ?? '') as String,
      orderId: (json['order_id'] ?? json['orderId'] ?? '') as String,
      plan: (json['plan'] ?? '') as String,
      amount: (json['amount'] ?? '0') as String,
      currency: (json['currency'] ?? 'CNY') as String,
      status: (json['status'] ?? 'unknown') as String,
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? '') as String,
      purchasedAt: (json['purchased_at'] ?? json['purchasedAt'] ?? '') as String,
      validFrom: (json['valid_from'] ?? json['validFrom'] ?? '') as String,
      validTo: (json['valid_to'] ?? json['validTo'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'plan': plan,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentMethod': paymentMethod,
      'purchasedAt': purchasedAt,
      'validFrom': validFrom,
      'validTo': validTo,
    };
  }

  // 获取计划显示名称
  String get planDisplayName {
    switch (plan) {
      case 'monthly':
        return '月度会员';
      case 'quarterly':
        return '季度会员';
      case 'yearly':
        return '年度会员';
      default:
        return plan;
    }
  }

  // 获取支付方式显示名称
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case 'alipay':
        return '支付宝';
      case 'stripe':
        return 'Stripe';
      case 'wechat':
        return '微信支付';
      case 'apple':
      case 'apple_iap':
        return 'Apple 支付';
      default:
        return paymentMethod;
    }
  }

  // 获取状态显示名称
  String get statusDisplayName {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'pending':
        return '待支付';
      case 'failed':
        return '支付失败';
      case 'refunded':
        return '已退款';
      default:
        return status;
    }
  }
}

// 兑换记录模型
class RedeemRecord {
  final String id;
  final String code;
  final String type;
  final String name;
  final int days;
  final String redeemedAt;
  final String validFrom;
  final String validTo;
  final String? previousExpiryDate;

  RedeemRecord({
    required this.id,
    required this.code,
    required this.type,
    required this.name,
    required this.days,
    required this.redeemedAt,
    required this.validFrom,
    required this.validTo,
    this.previousExpiryDate,
  });

  factory RedeemRecord.fromJson(Map<String, dynamic> json) {
    return RedeemRecord(
      id: (json['id'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      days: (json['days'] ?? 0) as int,
      redeemedAt: (json['redeemed_at'] ?? json['redeemedAt'] ?? '') as String,
      validFrom: (json['valid_from'] ?? json['validFrom'] ?? '') as String,
      validTo: (json['valid_to'] ?? json['validTo'] ?? '') as String,
      previousExpiryDate: json['previous_expiry_date'] ?? json['previousExpiryDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'type': type,
      'name': name,
      'days': days,
      'redeemedAt': redeemedAt,
      'validFrom': validFrom,
      'validTo': validTo,
      'previousExpiryDate': previousExpiryDate,
    };
  }
}

// 兑换码模型
class RedeemCode {
  final String code;
  final String type;
  final int days;
  final String name;
  final String? description;
  final String createdBy;
  final String createdAt;
  final bool used;
  final String? usedBy;
  final String? usedAt;

  RedeemCode({
    required this.code,
    required this.type,
    required this.days,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.used,
    this.usedBy,
    this.usedAt,
  });

  factory RedeemCode.fromJson(Map<String, dynamic> json) {
    return RedeemCode(
      code: json['code'] as String,
      type: json['type'] as String,
      days: json['days'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String,
      createdAt: json['createdAt'] as String,
      used: json['used'] as bool,
      usedBy: json['usedBy'] as String?,
      usedAt: json['usedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'type': type,
      'days': days,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'used': used,
      'usedBy': usedBy,
      'usedAt': usedAt,
    };
  }

  // 获取状态显示名称
  String get statusDisplayName => used ? '已使用' : '未使用';

  // 获取类型显示名称
  String get typeDisplayName {
    switch (type) {
      case 'trial':
        return '试用';
      case 'premium':
        return '会员';
      default:
        return type;
    }
  }
}
