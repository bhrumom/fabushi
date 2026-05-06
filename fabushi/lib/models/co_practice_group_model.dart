int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _asBool(dynamic value) => value == true || value == 1 || value == '1';

String _asString(dynamic value) => value?.toString() ?? '';

String _formatGroupCode(int id) => id.toString().padLeft(6, '0');

class CoPracticeGroup {
  final int id;
  final String name;
  final String description;
  final String ownerUsername;
  final String ownerName;
  final bool requireApproval;
  final int dailyGoalMinutes;
  final int cumulativeMissLimit;
  final int consecutiveMissLimit;
  final int memberCount;
  final int pendingCount;
  final int totalDuration;
  final int todayDuration;
  final String? myStatus;
  final String? myRole;
  final String? myWarningMessage;
  final DateTime? createdAt;

  const CoPracticeGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerUsername,
    required this.ownerName,
    required this.requireApproval,
    required this.dailyGoalMinutes,
    required this.cumulativeMissLimit,
    required this.consecutiveMissLimit,
    required this.memberCount,
    required this.pendingCount,
    required this.totalDuration,
    required this.todayDuration,
    this.myStatus,
    this.myRole,
    this.myWarningMessage,
    this.createdAt,
  });

  String get publicCode => _formatGroupCode(id);

  factory CoPracticeGroup.fromJson(Map<String, dynamic> json) {
    return CoPracticeGroup(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      ownerUsername: _asString(json['ownerUsername'] ?? json['owner_username']),
      ownerName: _asString(json['ownerName'] ?? json['owner_name']),
      requireApproval: _asBool(
        json['requireApproval'] ?? json['require_approval'],
      ),
      dailyGoalMinutes: _asInt(
        json['dailyGoalMinutes'] ?? json['daily_goal_minutes'],
      ),
      cumulativeMissLimit: _asInt(
        json['cumulativeMissLimit'] ?? json['cumulative_miss_limit'],
      ),
      consecutiveMissLimit: _asInt(
        json['consecutiveMissLimit'] ?? json['consecutive_miss_limit'],
      ),
      memberCount: _asInt(json['memberCount'] ?? json['member_count']),
      pendingCount: _asInt(json['pendingCount'] ?? json['pending_count']),
      totalDuration: _asInt(json['totalDuration'] ?? json['total_duration']),
      todayDuration: _asInt(json['todayDuration'] ?? json['today_duration']),
      myStatus: (json['myStatus'] ?? json['my_status'])?.toString(),
      myRole: (json['myRole'] ?? json['my_role'])?.toString(),
      myWarningMessage: (json['myWarningMessage'] ?? json['my_warning_message'])
          ?.toString(),
      createdAt: DateTime.tryParse(_asString(json['createdAt'])),
    );
  }
}

class CoPracticeMemberRank {
  final String username;
  final String displayName;
  final String? avatar;
  final String role;
  final int totalDuration;
  final int todayDuration;
  final int activeDays;
  final int rank;
  final int cumulativeMissedDays;
  final int consecutiveMissedDays;
  final String? warningMessage;

  const CoPracticeMemberRank({
    required this.username,
    required this.displayName,
    this.avatar,
    required this.role,
    required this.totalDuration,
    required this.todayDuration,
    required this.activeDays,
    required this.rank,
    required this.cumulativeMissedDays,
    required this.consecutiveMissedDays,
    this.warningMessage,
  });

  factory CoPracticeMemberRank.fromJson(Map<String, dynamic> json) {
    return CoPracticeMemberRank(
      username: _asString(json['username']),
      displayName: _asString(json['displayName'] ?? json['display_name']),
      avatar: (json['avatar'] ?? '').toString().isEmpty
          ? null
          : json['avatar'].toString(),
      role: _asString(json['role']).isEmpty
          ? 'member'
          : _asString(json['role']),
      totalDuration: _asInt(json['totalDuration'] ?? json['total_duration']),
      todayDuration: _asInt(json['todayDuration'] ?? json['today_duration']),
      activeDays: _asInt(json['activeDays'] ?? json['active_days']),
      rank: _asInt(json['rank']),
      cumulativeMissedDays: _asInt(
        json['cumulativeMissedDays'] ?? json['cumulative_missed_days'],
      ),
      consecutiveMissedDays: _asInt(
        json['consecutiveMissedDays'] ?? json['consecutive_missed_days'],
      ),
      warningMessage: (json['warningMessage'] ?? json['warning_message'])
          ?.toString(),
    );
  }
}

class CoPracticePendingMember {
  final String username;
  final String displayName;
  final String? avatar;
  final DateTime? updatedAt;

  const CoPracticePendingMember({
    required this.username,
    required this.displayName,
    this.avatar,
    this.updatedAt,
  });

  factory CoPracticePendingMember.fromJson(Map<String, dynamic> json) {
    return CoPracticePendingMember(
      username: _asString(json['username']),
      displayName: _asString(json['displayName'] ?? json['display_name']),
      avatar: (json['avatar'] ?? '').toString().isEmpty
          ? null
          : json['avatar'].toString(),
      updatedAt: DateTime.tryParse(
        _asString(json['updatedAt'] ?? json['updated_at']),
      ),
    );
  }
}

class CoPracticeGroupDetail {
  final CoPracticeGroup group;
  final List<CoPracticeMemberRank> members;
  final List<CoPracticePendingMember> pendingMembers;

  const CoPracticeGroupDetail({
    required this.group,
    required this.members,
    required this.pendingMembers,
  });

  factory CoPracticeGroupDetail.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List<dynamic>? ?? [];
    final pendingMembers = json['pendingMembers'] as List<dynamic>? ?? [];
    return CoPracticeGroupDetail(
      group: CoPracticeGroup.fromJson(
        Map<String, dynamic>.from(json['group'] as Map),
      ),
      members: members
          .map(
            (item) => CoPracticeMemberRank.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      pendingMembers: pendingMembers
          .map(
            (item) => CoPracticePendingMember.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
