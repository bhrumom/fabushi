import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../services/api_client.dart';

/// Lightweight platform account dashboard.
///
/// Historical Global Dharma transfer/practice/membership statistics belonged to
/// the standalone app and are intentionally not part of the host platform.
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
    final token = context.read<AuthModel>().authToken;
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
      } catch (error) {
        debugPrint('Failed to fetch AI quota: $error');
      }
    }
    if (mounted) setState(() => _isLoadingTokens = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthModel>(
      builder: (context, authModel, _) {
        final user = authModel.currentUser;
        final displayName = user?.displayName.trim().isNotEmpty == true
            ? user!.displayName.trim()
            : '未登录';
        final avatar = user?.avatar?.trim();
        final initial = displayName.isEmpty ? '大' : displayName.substring(0, 1);
        final handle = user?.userNo != null
            ? '@user_${user!.userNo}'
            : '@guest';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFF5A6668),
                  backgroundImage: avatar != null && avatar.startsWith('http')
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || !avatar.startsWith('http')
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        handle,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      if (user?.email.isNotEmpty == true)
                        Text(
                          user!.email,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.token_outlined, color: Color(0xFF40A7E3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '平台 AI 配额',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoadingTokens
                              ? '读取中…'
                              : '${_formatTokens(_usedTokens)} / ${_formatTokens(_monthlyLimit)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTokens(int count) {
    if (count >= 10000) {
      final value = count / 10000.0;
      return '${value == value.truncateToDouble() ? value.toInt() : value.toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}
