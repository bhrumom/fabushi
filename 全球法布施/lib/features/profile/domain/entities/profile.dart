import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String username;
  final String? email;
  final String? avatarUrl;
  final UserStats stats;

  const UserProfile({required this.username, this.email, this.avatarUrl, required this.stats});

  @override
  List<Object?> get props => [username, email, avatarUrl, stats];
}

class UserStats extends Equatable {
  final int totalTransfers;
  final int totalBytes;
  final int rank;

  const UserStats({required this.totalTransfers, required this.totalBytes, required this.rank});

  @override
  List<Object> get props => [totalTransfers, totalBytes, rank];
}
