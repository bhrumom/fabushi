import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../models/user_model.dart';
import '../../models/file_transfer_model.dart';
import '../../services/practice_stats_service.dart';
import 'activity_heatmap_widget.dart';
import '../../screens/edit_profile_screen.dart';

import '../../services/api_client.dart';

class CodexProfileDashboard extends StatefulWidget {
  const CodexProfileDashboard({super.key});

  @override
  State<CodexProfileDashboard> createState() => _CodexProfileDashboardState();
}

class _CodexProfileDashboardState extends State<CodexProfileDashboard> {
  int _usedTokens = 0;
  int _monthlyLimit = 0;
  bool _isLoadingTokens = true;

  @override
  void initState() {
    super.initState();
    _fetchAiQuota();
  }

  Future<void> _fetchAiQuota() async {
    final authModel = context.read<AuthModel>();
    final token = authModel.authToken;
    if (token != null) {
      try {
        final result = await ApiClient().getAiQuota(token);
        if (result['success'] == true && mounted) {
          setState(() {
            _usedTokens = result['usedTokens'] ?? 0;
            _monthlyLimit = result['monthlyLimit'] ?? 0;
            _isLoadingTokens = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Failed to fetch AI quota: $e');
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingTokens = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthModel, FileTransferModel>(
      builder: (context, authModel, transferModel, child) {
        final user = authModel.currentUser;
        final practiceService = PracticeStatsService();
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, user),
              const SizedBox(height: 32),
              ListenableBuilder(
                listenable: practiceService,
                builder: (context, _) => _buildStatsRow(transferModel, practiceService),
              ),
              const SizedBox(height: 32),
              _buildMembershipSection(user),
              const SizedBox(height: 48),
              _buildHeatmapSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    final displayName = user?.nickname ?? user?.username ?? '游客';
    final initials = displayName.length >= 2 
        ? displayName.substring(0, 2).toUpperCase() 
        : (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G');
    
    final handle = user?.userNo != null ? '@user_${user!.userNo}' : '@guest';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFF5A6668),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              handle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '·',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '活跃',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          child: const Text('编辑资料', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  String _formatTokens(int count) {
    if (count >= 10000) {
      double w = count / 10000.0;
      return '${w == w.truncateToDouble() ? w.toInt() : w.toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  Widget _buildStatsRow(FileTransferModel transferModel, PracticeStatsService practiceService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _isLoadingTokens
              ? _buildStatItem('-', 'AI Tokens')
              : _buildStatItem('${_formatTokens(_usedTokens)}/${_formatTokens(_monthlyLimit)}', 'AI Tokens'),
          _buildVerticalDivider(),
          _buildStatItem('${transferModel.globalSentCount}', '全球法布施(次)'),
          _buildVerticalDivider(),
          _buildStatItem('${transferModel.globalDataSentMB.toStringAsFixed(1)}MB', '法布施流量'),
          _buildVerticalDivider(),
          _buildStatItem('${practiceService.stats.total.duration}', '修行(分钟)'),
          _buildVerticalDivider(),
          _buildStatItem('${practiceService.stats.total.days}', '累计修行(天)'),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipSection(User? user) {
    final bool isMember = user?.membershipType != null && user!.membershipType!.isNotEmpty;
    final String type = isMember ? user.membershipType! : '普通用户';
    final String expiry = user?.membershipExpiry != null 
        ? '${user!.membershipExpiry!.year}-${user.membershipExpiry!.month.toString().padLeft(2, '0')}-${user.membershipExpiry!.day.toString().padLeft(2, '0')} 过期'
        : '未开通会员或已过期';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMember 
              ? [const Color(0xFFD4AF37).withOpacity(0.2), const Color(0xFFD4AF37).withOpacity(0.05)]
              : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMember ? const Color(0xFFD4AF37).withOpacity(0.3) : Colors.white.withOpacity(0.05)
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.diamond_outlined, 
                    color: isMember ? const Color(0xFFD4AF37) : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: isMember ? const Color(0xFFD4AF37) : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                expiry,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to Membership renewal screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isMember ? const Color(0xFFD4AF37) : Colors.white12,
              foregroundColor: isMember ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(isMember ? '续费' : '升级'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection() {
    return const ActivityHeatmapWidget();
  }
}
