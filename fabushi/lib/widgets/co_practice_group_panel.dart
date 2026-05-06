import 'dart:async';

import 'package:flutter/material.dart';

import '../models/co_practice_group_model.dart';
import '../services/co_practice_service.dart';

class CoPracticeGroupPanel extends StatefulWidget {
  const CoPracticeGroupPanel({super.key});

  @override
  State<CoPracticeGroupPanel> createState() => _CoPracticeGroupPanelState();
}

class _CoPracticeGroupPanelState extends State<CoPracticeGroupPanel> {
  final _service = CoPracticeService();
  final _searchController = TextEditingController();
  late Future<List<CoPracticeGroup>> _future;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<CoPracticeGroup>> _load() {
    return _service.searchGroups(query: _searchController.text.trim());
  }

  void _refresh() {
    final future = _load();
    setState(() => _future = future);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _CreateCoPracticeGroupDialog(),
    );
    if (created == true) _refresh();
  }

  Future<void> _openDetail(CoPracticeGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _CoPracticeGroupDetailSheet(groupId: group.id),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.24),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '共修小组入口',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '先搜索小组名、组主或标准群号，点开后即可申请加入；创建者点开自己的小组，就能在详情页里看到待审批成员。',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索小组名、组主或群号 #000123',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _refresh();
                          },
                          icon: const Icon(Icons.close, color: Colors.white54),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF222222),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: '创建小组',
              child: IconButton.filled(
                onPressed: _showCreateDialog,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<CoPracticeGroup>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                );
              }

              final groups = snapshot.data ?? [];
              if (groups.isEmpty) {
                return const Center(
                  child: Text(
                    '暂无共修小组',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.separated(
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _CoPracticeGroupTile(
                    group: group,
                    onTap: () => _openDetail(group),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CoPracticeGroupTile extends StatelessWidget {
  final CoPracticeGroup group;
  final VoidCallback onTap;

  const _CoPracticeGroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusChip(group: group),
                ],
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  group.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    '组主 ${group.ownerName}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  _InfoPill(
                    icon: Icons.tag_outlined,
                    text: '群号 #${group.publicCode}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoPill(
                    icon: Icons.timer_outlined,
                    text: '累计 ${_formatMinutes(group.totalDuration)}',
                  ),
                  _InfoPill(
                    icon: Icons.today_outlined,
                    text: '今日 ${_formatMinutes(group.todayDuration)}',
                  ),
                  _InfoPill(
                    icon: Icons.flag_outlined,
                    text: '日目标 ${group.dailyGoalMinutes} 分钟',
                  ),
                  _InfoPill(
                    icon: Icons.group_outlined,
                    text: '${group.memberCount} 人',
                  ),
                  if (group.myRole == 'owner')
                    _InfoPill(
                      icon: Icons.admin_panel_settings_outlined,
                      text: group.pendingCount > 0
                          ? '待审批 ${group.pendingCount}'
                          : '组主管理',
                    ),
                  if (group.myStatus == null ||
                      group.myStatus == 'removed' ||
                      group.myStatus == 'rejected')
                    _InfoPill(
                      icon: Icons.travel_explore_outlined,
                      text: group.requireApproval ? '点开申请加入' : '点开直接加入',
                    ),
                ],
              ),
              if (group.myWarningMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _WarningStrip(message: group.myWarningMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CoPracticeGroup group;

  const _StatusChip({required this.group});

  @override
  Widget build(BuildContext context) {
    final status = group.myStatus;
    final text = switch (status) {
      'active' => '已加入',
      'pending' => '待同意',
      'removed' => '已清退',
      'rejected' => '未通过',
      _ => group.requireApproval ? '需同意' : '可加入',
    };
    final color = switch (status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      'removed' || 'rejected' => Colors.redAccent,
      _ => const Color(0xFFD4AF37),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WarningStrip extends StatelessWidget {
  final String message;

  const _WarningStrip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoPracticeGroupDetailSheet extends StatefulWidget {
  final int groupId;

  const _CoPracticeGroupDetailSheet({required this.groupId});

  @override
  State<_CoPracticeGroupDetailSheet> createState() =>
      _CoPracticeGroupDetailSheetState();
}

class _CoPracticeGroupDetailSheetState
    extends State<_CoPracticeGroupDetailSheet> {
  final _service = CoPracticeService();
  late Future<CoPracticeGroupDetail?> _future;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchGroupDetail(widget.groupId);
  }

  void _reload() {
    setState(() => _future = _service.fetchGroupDetail(widget.groupId));
  }

  Future<void> _join() async {
    setState(() => _isWorking = true);
    final message = await _service.joinGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _isWorking = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message ?? '加入失败，请稍后再试')));
    _reload();
  }

  Future<void> _review(String username, bool approve) async {
    setState(() => _isWorking = true);
    final ok = await _service.reviewJoinRequest(
      groupId: widget.groupId,
      username: username,
      approve: approve,
    );
    if (!mounted) return;
    setState(() => _isWorking = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '已处理申请' : '处理失败')));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: FutureBuilder<CoPracticeGroupDetail?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              );
            }

            final detail = snapshot.data;
            if (detail == null) {
              return const Center(
                child: Text('小组加载失败', style: TextStyle(color: Colors.white54)),
              );
            }

            final group = detail.group;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.groups_2, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _StatusChip(group: group),
                    ],
                  ),
                  if (group.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      group.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.person_outline,
                        text: '组主 ${group.ownerName}',
                      ),
                      _InfoPill(
                        icon: Icons.tag_outlined,
                        text: '群号 #${group.publicCode}',
                      ),
                      _InfoPill(
                        icon: Icons.timer_outlined,
                        text: '累计 ${_formatMinutes(group.totalDuration)}',
                      ),
                      _InfoPill(
                        icon: Icons.flag_outlined,
                        text: '日目标 ${group.dailyGoalMinutes} 分钟',
                      ),
                      _InfoPill(
                        icon: Icons.rule,
                        text:
                            '累计 ${group.cumulativeMissLimit} / 连续 ${group.consecutiveMissLimit}',
                      ),
                      if (group.myRole == 'owner')
                        _InfoPill(
                          icon: Icons.mark_email_unread_outlined,
                          text: group.pendingCount > 0
                              ? '待审批 ${group.pendingCount} 人'
                              : '暂无待审批',
                        ),
                    ],
                  ),
                  if (group.myWarningMessage?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _WarningStrip(message: group.myWarningMessage!),
                  ],
                  const SizedBox(height: 14),
                  if (group.myStatus != 'active' && group.myStatus != 'pending')
                    ElevatedButton.icon(
                      onPressed: _isWorking ? null : _join,
                      icon: const Icon(Icons.login),
                      label: Text(group.requireApproval ? '申请加入' : '加入小组'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (group.myStatus == 'pending') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            color: Colors.orange,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '申请已经发出，创建者点开这个小组详情页，就能在下方“待同意成员”里审批。',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (detail.pendingMembers.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      '待同意成员',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...detail.pendingMembers.map(
                      (member) => _PendingMemberTile(
                        member: member,
                        isWorking: _isWorking,
                        onApprove: () => _review(member.username, true),
                        onReject: () => _review(member.username, false),
                      ),
                    ),
                  ],
                  if (group.myRole == 'owner' &&
                      detail.pendingMembers.isEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Color(0xFFD4AF37),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '这里就是小组管理与审批入口。别人申请加入后，会直接出现在这里。',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    '小组排行',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detail.members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '暂无成员数据',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    ...detail.members.map(_MemberRankTile.new),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingMemberTile extends StatelessWidget {
  final CoPracticePendingMember member;
  final bool isWorking;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingMemberTile({
    required this.member,
    required this.isWorking,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _Avatar(name: member.displayName, avatar: member.avatar, rank: null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: '同意',
            onPressed: isWorking ? null : onApprove,
            icon: const Icon(Icons.check, color: Colors.green),
          ),
          IconButton(
            tooltip: '拒绝',
            onPressed: isWorking ? null : onReject,
            icon: const Icon(Icons.close, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _MemberRankTile extends StatelessWidget {
  final CoPracticeMemberRank member;

  const _MemberRankTile(this.member);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            name: member.displayName,
            avatar: member.avatar,
            rank: member.rank,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (member.role == 'owner')
                      const Icon(
                        Icons.verified,
                        color: Color(0xFFD4AF37),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '今日 ${_formatMinutes(member.todayDuration)} · ${member.activeDays} 天',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (member.warningMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    member.warningMessage!,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatMinutes(member.totalDuration),
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final int? rank;

  const _Avatar({required this.name, this.avatar, this.rank});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white10,
      backgroundImage: avatar?.isNotEmpty == true
          ? NetworkImage(avatar!)
          : null,
      child: avatar?.isNotEmpty == true
          ? null
          : Text(
              rank?.toString() ?? (name.isEmpty ? '?' : name.substring(0, 1)),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _CreateCoPracticeGroupDialog extends StatefulWidget {
  const _CreateCoPracticeGroupDialog();

  @override
  State<_CreateCoPracticeGroupDialog> createState() =>
      _CreateCoPracticeGroupDialogState();
}

class _CreateCoPracticeGroupDialogState
    extends State<_CreateCoPracticeGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController(text: '30');
  final _cumulativeController = TextEditingController(text: '7');
  final _consecutiveController = TextEditingController(text: '3');
  bool _requireApproval = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _cumulativeController.dispose();
    _consecutiveController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final dailyGoal = int.tryParse(_goalController.text.trim()) ?? 0;
    final cumulativeLimit =
        int.tryParse(_cumulativeController.text.trim()) ?? 0;
    final consecutiveLimit =
        int.tryParse(_consecutiveController.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入小组名称')));
      return;
    }
    if (dailyGoal <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每日目标需大于 0 分钟')));
      return;
    }

    setState(() => _isLoading = true);
    final result = await CoPracticeService().createGroup(
      name: name,
      description: _descriptionController.text.trim(),
      requireApproval: _requireApproval,
      dailyGoalMinutes: dailyGoal,
      cumulativeMissLimit: cumulativeLimit,
      consecutiveMissLimit: consecutiveLimit,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.groupId != null) {
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('共修小组已创建')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '创建失败，请先登录并检查网络'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '创建共修小组',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            _darkTextField(_nameController, '小组名称'),
            const SizedBox(height: 10),
            _darkTextField(_descriptionController, '简介（可选）', maxLines: 2),
            const SizedBox(height: 10),
            _darkTextField(
              _goalController,
              '每日目标（分钟）',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _darkTextField(
                    _cumulativeController,
                    '累计未达标清退',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _darkTextField(
                    _consecutiveController,
                    '连续未达标清退',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _requireApproval,
              onChanged: (value) => setState(() => _requireApproval = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFFD4AF37),
              title: const Text(
                '加入需要同意',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('创建'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0 分钟';
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  final remain = minutes % 60;
  return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
}
