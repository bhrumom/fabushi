import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'keep_alive_guide_screen.dart';
import '../services/app_settings.dart';
import '../models/auth_model.dart';

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
                    icon: Icons.refresh,
                    iconColor: Colors.cyan,
                    title: '刷新数据',
                    subtitle: '重新同步账户信息',
                    onTap: () async {
                      final authModel = Provider.of<AuthModel>(context, listen: false);
                      await authModel.refreshUserInfo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('数据已刷新'), backgroundColor: Colors.green),
                        );
                      }
                    },
                  ),

                  _buildSettingItem(
                    context,
                    icon: Icons.help_outline,
                    iconColor: Colors.orange,
                    title: '帮助与反馈',
                    subtitle: '常见问题与意见反馈',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('帮助功能开发中')),
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

                  _buildLogoutItem(context),
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

  /// 退出登录按钮
  Widget _buildLogoutItem(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
        ),
        title: const Text(
          '退出登录',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          '退出当前账号',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('确认退出', style: TextStyle(color: Colors.white)),
              content: const Text('确定要退出登录吗？', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('退出', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final authModel = Provider.of<AuthModel>(context, listen: false);
            await authModel.logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
              Navigator.pop(context); // 返回上一页
            }
          }
        },
      ),
    );
  }
}
