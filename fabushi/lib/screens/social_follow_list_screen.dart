import 'package:flutter/material.dart';

import '../services/social_service.dart';
import '../widgets/follow_button.dart';

class SocialFollowListScreen extends StatefulWidget {
  final String? username;
  final int initialTabIndex;

  const SocialFollowListScreen({
    super.key,
    this.username,
    this.initialTabIndex = 0,
  });

  @override
  State<SocialFollowListScreen> createState() => _SocialFollowListScreenState();
}

class _SocialFollowListScreenState extends State<SocialFollowListScreen> {
  late Future<List<Map<String, dynamic>>> _followingFuture;
  late Future<List<Map<String, dynamic>>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _followingFuture = SocialService().fetchFollowList(
      type: 'following',
      username: widget.username,
    );
    _followersFuture = SocialService().fetchFollowList(
      type: 'followers',
      username: widget.username,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_followingFuture, _followersFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('关注关系'),
          backgroundColor: const Color(0xFF121212),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Color(0xFFD4AF37),
            labelColor: Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white54,
            tabs: [Tab(text: '我关注的'), Tab(text: '关注我的')],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: TabBarView(
            children: [
              _UserList(future: _followingFuture, emptyText: '暂无关注'),
              _UserList(future: _followersFuture, emptyText: '暂无粉丝'),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final String emptyText;

  const _UserList({required this.future, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 150),
              const Icon(Icons.people_outline, color: Colors.white24, size: 56),
              const SizedBox(height: 12),
              Center(child: Text(emptyText, style: const TextStyle(color: Colors.white54))),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            final username = user['username']?.toString() ?? '';
            final displayName = user['displayName']?.toString() ?? username;
            final avatar = user['avatar']?.toString();
            final followerCount = _asInt(user['followerCount']);
            final followingCount = _asInt(user['followingCount']);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.white10,
                backgroundImage: avatar?.isNotEmpty == true ? NetworkImage(avatar!) : null,
                child: avatar?.isNotEmpty == true
                    ? null
                    : Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('$followerCount 粉丝 · 关注 $followingCount', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: FollowButton(
                username: username,
                initialIsFollowing: user['isFollowing'] == true,
                isSelf: user['isSelf'] == true,
              ),
            );
          },
        );
      },
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
