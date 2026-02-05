import 'package:equatable/equatable.dart';

class MembershipPlan extends Equatable {
  final String id;
  final String name;
  final int days;
  final String price;
  final String currency;

  const MembershipPlan({
    required this.id,
    required this.name,
    required this.days,
    required this.price,
    required this.currency,
  });

  @override
  List<Object> get props => [id, name, days, price, currency];
}

class RedeemCode extends Equatable {
  final String code;
  final String type;
  final int days;
  final bool used;

  const RedeemCode({
    required this.code,
    required this.type,
    required this.days,
    required this.used,
  });

  @override
  List<Object> get props => [code, type, days, used];
}
