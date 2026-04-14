import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/auth_model.dart';
import '../services/favorite_service.dart';
import '../services/practice_stats_service.dart';
import 'liked_content_screen.dart';
import 'membership_screen.dart';
import 'edit_profile_screen.dart';
import 'douyin_login_screen.dart';
import 'settings_screen.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/practice_entry_card.dart';
import '../services/meditation_session_manager.dart';
import 'practice_record_screen.dart';


/// 抖音风格个人中心页面
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Consumer<AuthModel>(
          builder: (context, authModel, _) {
            final user = authModel.currentUser;
            
            // 设置统计服务的Token
            if (user != null && authModel.authToken != null) {
              PracticeStatsService().setAuthToken(authModel.authToken);
            }
            
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverAppBar(context, user, authModel),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (user != null) ...[
                            const SizedBox(height: 20),
                            _buildPracticeStatsCard(context),
                            const SizedBox(height: 20),
                            _buildMembershipCard(context, user),
                            const SizedBox(height: 20),
                            _buildFeatureGrid(context),
                          ] else ...[
                            const SizedBox(height: 20),
                            _buildGuestCard(context),
                            const SizedBox(height: 20),
                            _buildLoginButton(context),
                          ],
                          const SizedBox(height: 40), // Space before tabs
                        ],
                      ),
                    ),
                  ),
                  // Removed SliverPersistentHeader for TabBar
                ];
              },
              body: user != null
                  ? _buildFavoritesTab()
                  : const Center(child: Text('请先登录', style: TextStyle(color: Colors.white54))),
            );
          },
        ),
      );
  }

  Widget _buildFavoritesTab() {
    final favoriteService = FavoriteService();
    return ListenableBuilder(
      listenable: favoriteService,
      builder: (context, _) {
        final items = favoriteService.getFavoritedItems();
        
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '还没有收藏的内容',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  '您在此设备暂无收藏',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.contentType == 'video' ? Icons.videocam : Icons.article,
                    color: Colors.amber.shade700,
                  ),
                ),
                title: Text(
                  item.title.isNotEmpty ? item.title : '未命名内容',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatFavoriteTime(item.favoritedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark, color: Colors.amber),
                  onPressed: () async {
                    await favoriteService.toggleFavorite(item);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已取消收藏'), duration: Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatFavoriteTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 修行记录入口卡片
  Widget _buildPracticeStatsCard(BuildContext context) {
    return PracticeEntryCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PracticeRecordScreen()),
        );
      },
    );
  }


  Widget _buildSliverAppBar(BuildContext context, User? user, AuthModel authModel) {
    return SliverAppBar(
      expandedHeight: user != null ? 260 : 200,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      actions: [
        if (user != null)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2D2D2D), Color(0xFF121212)],
                ),
              ),
            ),
            // 用户信息
            if (user != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 头像
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 2),
                                    image: user.avatar != null
                                        ? DecorationImage(
                                            image: NetworkImage(user.avatar!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    gradient: user.avatar == null
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                                          )
                                        : null,
                                  ),
                                  child: user.avatar == null
                                      ? Center(
                                          child: Text(
                                            (user.displayName.isNotEmpty ? user.displayName[0] : '?').toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 用户名和ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '一门深入: ${MeditationSessionManager().lockedPractice?.title ?? '未选择'}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (user.isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Colors.purple, Colors.deepPurple],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          '管理员',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // 编辑资料按钮
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white30),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('编辑资料', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.person_outline, size: 50, color: Colors.white54),
                      ),
                      const SizedBox(height: 16),
                      const Text('游客模式', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('登录后享受更多功能', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  /// 功能网格 - 抖音风格
  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildFeatureItem(
          icon: Icons.card_membership,
          label: '会员',
          gradient: const [Color(0xFFD4AF37), Color(0xFFC5A028)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
        ),
        _buildFeatureItem(
          icon: Icons.favorite,
          label: '收藏',
          gradient: const [Color(0xFFFF6B6B), Color(0xFFEE5A5A)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedContentScreen())),
        ),
        _buildFeatureItem(
          icon: Icons.history,
          label: '历史',
          gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('浏览历史开发中'))),
        ),
        _buildFeatureItem(
          icon: Icons.download,
          label: '下载',
          gradient: const [Color(0xFF11998e), Color(0xFF38ef7d)],
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载管理开发中'))),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 会员卡片
  Widget _buildMembershipCard(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.diamond, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.membershipType ?? '普通用户',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  user.membershipExpiry != null
                      ? '有效期至 ${user.membershipExpiry!.year}.${user.membershipExpiry!.month}.${user.membershipExpiry!.day}'
                      : '升级会员解锁更多功能',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('升级', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 游客卡片
  Widget _buildGuestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
              SizedBox(width: 8),
              Text('游客可用功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuestFeatureItem(Icons.public, '全球法布施'),

          _buildGuestFeatureItem(Icons.self_improvement, '禅室体验'),
          const SizedBox(height: 12),
          const Text(
            '登录后可同步数据、使用会员功能等',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFeatureItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  /// 登录按钮
  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DouyinLoginScreen())),
          child: const Center(
            child: Text(
              '立即登录 / 注册',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

/// TabBar 的 SliverPersistentHeaderDelegate
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF121212),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
