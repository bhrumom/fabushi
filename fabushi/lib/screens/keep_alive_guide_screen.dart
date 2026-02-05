import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// 后台保活设置引导页面
/// 帮助用户设置自启动、电池优化等权限，确保后台发送不被系统杀掉
class KeepAliveGuideScreen extends StatefulWidget {
  const KeepAliveGuideScreen({super.key});

  @override
  State<KeepAliveGuideScreen> createState() => _KeepAliveGuideScreenState();
}

class _KeepAliveGuideScreenState extends State<KeepAliveGuideScreen> {
  String _deviceBrand = '';
  bool _isBatteryOptimizationIgnored = false;
  bool _isLoading = true;

  // 获取设备品牌的 Method Channel
  static const _platform = MethodChannel('com.ombhrum.fabushi/device_info');

  @override
  void initState() {
    super.initState();
    _checkDeviceAndPermissions();
  }

  Future<void> _checkDeviceAndPermissions() async {
    try {
      // 获取设备品牌
      if (Platform.isAndroid) {
        try {
          final brand = await _platform.invokeMethod<String>('getDeviceBrand');
          _deviceBrand = brand?.toLowerCase() ?? '';
        } catch (e) {
          // 如果 Method Channel 失败，尝试使用常见品牌关键词检测
          debugPrint('获取设备品牌失败，使用默认检测: $e');
          _deviceBrand = '';
        }
      }

      // 检查电池优化状态
      final status = await Permission.ignoreBatteryOptimizations.status;
      _isBatteryOptimizationIgnored = status.isGranted;
    } catch (e) {
      debugPrint('检查设备信息失败: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('后台保活设置'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 说明卡片
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, 
                               color: Colors.orange.shade700, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '为什么需要设置？',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '安卓系统会自动清理后台应用以省电。'
                                  '完成以下设置后，循环发送功能才能持续运行。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 设置项列表
                  _buildSettingItem(
                    icon: Icons.battery_saver,
                    title: '关闭电池优化',
                    subtitle: _isBatteryOptimizationIgnored 
                        ? '已关闭 ✓' 
                        : '允许应用在后台运行',
                    isCompleted: _isBatteryOptimizationIgnored,
                    onTap: _requestBatteryOptimization,
                  ),
                  _buildSettingItem(
                    icon: Icons.play_circle_outline,
                    title: '开启自启动',
                    subtitle: _getBrandSpecificAutoStartHint(),
                    onTap: _openAutoStartSettings,
                  ),
                  _buildSettingItem(
                    icon: Icons.lock_outline,
                    title: '锁定最近任务',
                    subtitle: '在最近应用中下拉锁定本应用',
                    onTap: () => _showLockTaskGuide(context),
                  ),
                  _buildSettingItem(
                    icon: Icons.settings,
                    title: '应用详情设置',
                    subtitle: '检查其他后台运行相关权限',
                    onTap: _openAppSettings,
                  ),

                  // 厂商专属提示
                  if (_deviceBrand.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildBrandSpecificTips(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isCompleted = false,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCompleted 
                ? Colors.green.shade100 
                : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : icon,
            color: isCompleted ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }

  String _getBrandSpecificAutoStartHint() {
    switch (_deviceBrand) {
      case 'oneplus':
      case 'oppo':
      case 'realme':
        return '设置 → 电池 → 自启动管理';
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return '设置 → 应用设置 → 自启动';
      case 'huawei':
      case 'honor':
        return '设置 → 应用 → 启动管理';
      case 'vivo':
        return '设置 → 电池 → 后台高耗电';
      case 'samsung':
        return '设置 → 电池 → 后台使用限制';
      default:
        return '在系统设置中找到自启动管理';
    }
  }

  Widget _buildBrandSpecificTips() {
    String brandName = _deviceBrand.toUpperCase();
    String tips = '';

    switch (_deviceBrand) {
      case 'oneplus':
      case 'oppo':
      case 'realme':
        brandName = _deviceBrand == 'oneplus' ? '一加' : 
                    _deviceBrand == 'oppo' ? 'OPPO' : 'realme';
        tips = '1. 打开「设置 → 电池 → 更多电池设置」\n'
               '2. 关闭「睡眠待机优化」\n'
               '3. 在「自启动管理」中允许本应用\n'
               '4. 在「省电策略」中选择「无限制」';
        break;
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        brandName = '小米/红米';
        tips = '1. 打开「设置 → 应用设置 → 应用管理」\n'
               '2. 找到本应用，开启「自启动」\n'
               '3. 在「省电策略」中选择「无限制」\n'
               '4. 关闭「锁屏后清理」';
        break;
      case 'huawei':
      case 'honor':
        brandName = '华为/荣耀';
        tips = '1. 打开「设置 → 应用 → 应用启动管理」\n'
               '2. 关闭本应用的「自动管理」\n'
               '3. 手动开启「自启动」「后台活动」「关联启动」';
        break;
      case 'vivo':
        brandName = 'vivo';
        tips = '1. 打开「设置 → 电池 → 后台高耗电」\n'
               '2. 允许本应用在后台高耗电\n'
               '3. 在「自启动管理」中允许本应用';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '$brandName 专属设置',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tips,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (mounted) {
        setState(() {
          _isBatteryOptimizationIgnored = status.isGranted;
        });
        
        if (status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ 已关闭电池优化'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('请求电池优化权限失败: $e');
    }
  }

  Future<void> _openAutoStartSettings() async {
    try {
      // 尝试打开厂商自启动页面
      String? intentAction;
      
      switch (_deviceBrand) {
        case 'oneplus':
        case 'oppo':
        case 'realme':
          // ColorOS 自启动管理
          intentAction = 'com.coloros.safecenter';
          break;
        case 'xiaomi':
        case 'redmi':
        case 'poco':
          // MIUI 自启动管理
          intentAction = 'com.miui.securitycenter';
          break;
        case 'huawei':
        case 'honor':
          // EMUI 启动管理
          intentAction = 'com.huawei.systemmanager';
          break;
        case 'vivo':
          // Funtouch OS
          intentAction = 'com.iqoo.secure';
          break;
      }

      // 如果有厂商特定包名，尝试打开
      if (intentAction != null) {
        final Uri uri = Uri.parse('package:$intentAction');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }

      // 降级到应用设置
      await openAppSettings();
    } catch (e) {
      debugPrint('打开自启动设置失败: $e');
      await openAppSettings();
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  void _showLockTaskGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('锁定任务指南'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 按下「最近任务」按钮（方形或手势上滑）'),
            SizedBox(height: 8),
            Text('2. 找到本应用的卡片'),
            SizedBox(height: 8),
            Text('3. 长按或下拉卡片，点击「锁定」图标 🔒'),
            SizedBox(height: 12),
            Text(
              '锁定后，清理后台时不会关闭本应用',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
