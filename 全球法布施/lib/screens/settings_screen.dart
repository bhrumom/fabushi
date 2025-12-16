import 'dart:io';
import 'package:flutter/material.dart';
import 'keep_alive_guide_screen.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _defaultTtsMuted = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final defaultMuted = await AppSettings.getDefaultTtsMuted();
    if (mounted) {
      setState(() {
        _defaultTtsMuted = defaultMuted;
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultTtsMuted(bool value) async {
    setState(() => _defaultTtsMuted = value);
    await AppSettings.setDefaultTtsMuted(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TTS 默认静音设置
                  _buildTtsMuteSettingItem(),

                  // Android 后台保活设置（仅 Android 显示）
                  if (Platform.isAndroid)
                    _buildSettingItem(
                      context,
                      icon: Icons.battery_saver,
                      iconColor: Colors.green,
                      title: '后台保活设置',
                      subtitle: '防止应用被系统清理',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const KeepAliveGuideScreen()),
                      ),
                    ),

                  _buildSettingItem(
                    context,
                    icon: Icons.info_outline,
                    iconColor: Colors.blue,
                    title: '关于',
                    subtitle: '版本 1.0.0',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: '全球法布施',
                      applicationVersion: '1.0.0',
                      children: [const Text('传播佛法，利益众生')],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// TTS默认静音设置项
  Widget _buildTtsMuteSettingItem() {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.volume_off, color: Colors.amber, size: 24),
        ),
        title: const Text(
          '启动默认静音',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _defaultTtsMuted ? '法流页面TTS朗读默认静音' : '法流页面TTS朗读默认开启',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: Switch(
          value: _defaultTtsMuted,
          onChanged: _setDefaultTtsMuted,
          activeColor: Colors.amber,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
