import 'package:flutter/material.dart';
import '../services/eula_service.dart';

/// 用户协议（EULA）同意页面
///
/// 首次使用或协议更新时强制显示，用户必须同意后才能继续使用应用
class EulaScreen extends StatefulWidget {
  final VoidCallback? onAccepted;

  const EulaScreen({super.key, this.onAccepted});

  /// 检查并显示 EULA（如需要）
  static Future<bool> checkAndShow(BuildContext context) async {
    final accepted = await EulaService.isAccepted();
    if (accepted) return true;

    if (!context.mounted) return false;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const EulaScreen(),
      ),
    );
    return result ?? false;
  }

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _isScrolledToBottom = false;
  bool _agreedToTerms = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_isScrolledToBottom) {
        setState(() => _isScrolledToBottom = true);
      }
    }
  }

  Future<void> _acceptEula() async {
    await EulaService.accept();
    widget.onAccepted?.call();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('用户协议与隐私政策'),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 协议内容
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EulaService.getEulaText(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      EulaService.getPrivacyPolicyText(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 同意勾选框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: _isScrolledToBottom
                        ? (value) =>
                              setState(() => _agreedToTerms = value ?? false)
                        : null,
                    activeColor: const Color(0xFF667EEA),
                    side: BorderSide(
                      color: _isScrolledToBottom
                          ? Colors.white54
                          : Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isScrolledToBottom
                        ? '我已阅读并同意《用户协议》和《隐私政策》'
                        : '请先阅读完整协议内容（滑动到底部）',
                    style: TextStyle(
                      color: _isScrolledToBottom
                          ? Colors.white70
                          : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 底部按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Row(
              children: [
                // 不同意按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('不同意'),
                  ),
                ),
                const SizedBox(width: 16),
                // 同意按钮
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _agreedToTerms ? _acceptEula : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      disabledBackgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white30,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '同意并继续',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
