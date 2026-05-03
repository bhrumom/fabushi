import 'package:flutter/material.dart';

import '../services/social_service.dart';

class PracticePrivacyScreen extends StatefulWidget {
  const PracticePrivacyScreen({super.key});

  @override
  State<PracticePrivacyScreen> createState() => _PracticePrivacyScreenState();
}

class _PracticePrivacyScreenState extends State<PracticePrivacyScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _isPrivate = false;
  bool _showPracticeName = true;
  bool _showDuration = true;
  bool _showChantCount = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final privacy = await SocialService().fetchPracticePrivacy();
    if (!mounted) return;
    setState(() {
      _isPrivate = privacy['isPrivate'] == true;
      _showPracticeName = privacy['showPracticeName'] != false;
      _showDuration = privacy['showDuration'] != false;
      _showChantCount = privacy['showChantCount'] != false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await SocialService().updatePracticePrivacy(
      isPrivate: _isPrivate,
      showPracticeName: _showPracticeName,
      showDuration: _showDuration,
      showChantCount: _showChantCount,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '修行隐私设置已保存' : '保存失败，请稍后重试')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('修行隐私'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _IntroCard(isPrivate: _isPrivate),
                const SizedBox(height: 16),
                _buildSwitch(
                  title: '功课记录设为私密',
                  subtitle: '开启后，别人看不到你的公开修行记录明细。排行榜只展示昵称与头像。',
                  value: _isPrivate,
                  onChanged: (value) => setState(() => _isPrivate = value),
                ),
                const SizedBox(height: 12),
                IgnorePointer(
                  ignoring: _isPrivate,
                  child: Opacity(
                    opacity: _isPrivate ? 0.45 : 1,
                    child: Column(
                      children: [
                        _buildSwitch(
                          title: '公开功课名称',
                          subtitle: '例如：公开“地藏经”“佛号”等功课名称。关闭后只显示“修行功课”。',
                          value: _showPracticeName,
                          onChanged: (value) => setState(() => _showPracticeName = value),
                        ),
                        const SizedBox(height: 12),
                        _buildSwitch(
                          title: '公开修行时长',
                          subtitle: '开启后，排行榜和记录明细可展示分钟数。关闭后隐藏时长。',
                          value: _showDuration,
                          onChanged: (value) => setState(() => _showDuration = value),
                        ),
                        const SizedBox(height: 12),
                        _buildSwitch(
                          title: '公开念诵遍数',
                          subtitle: '开启后公开遍数统计；关闭后隐藏具体遍数。',
                          value: _showChantCount,
                          onChanged: (value) => setState(() => _showChantCount = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存设置', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeColor: const Color(0xFFD4AF37),
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool isPrivate;

  const _IntroCard({required this.isPrivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPrivate
              ? const [Color(0xFF323232), Color(0xFF1E1E1E)]
              : const [Color(0xFF3A3020), Color(0xFF1E1E1E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPrivate ? Icons.lock_outline : Icons.visibility_outlined, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '你可以按字段控制公开范围：只公开修行时间、不公开具体功课；或公开功课、不公开修行时间。心得和备注默认不公开。',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
