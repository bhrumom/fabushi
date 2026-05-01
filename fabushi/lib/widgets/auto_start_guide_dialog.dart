import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自启动设置引导弹窗
///
/// 引导用户开启厂商的自启动/后台运行白名单，
/// 这是实现长时间后台运行的关键步骤。
class AutoStartGuideDialog extends StatefulWidget {
  /// 是否在发送开始时显示（首次）
  final bool isFirstTime;

  const AutoStartGuideDialog({super.key, this.isFirstTime = false});

  /// 显示自启动设置引导弹窗
  ///
  /// [force] 为 true 时强制显示，否则只在首次使用时显示
  static Future<void> showIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('auto_start_guide_shown') ?? false;

    if (force || !hasShown) {
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AutoStartGuideDialog(isFirstTime: !hasShown),
        );
        await prefs.setBool('auto_start_guide_shown', true);
      }
    }
  }

  @override
  State<AutoStartGuideDialog> createState() => _AutoStartGuideDialogState();
}

class _AutoStartGuideDialogState extends State<AutoStartGuideDialog> {
  static const _channel = MethodChannel('com.ombhrum.fabushi/device_info');

  String _manufacturer = '';
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _getManufacturer();
  }

  Future<void> _getManufacturer() async {
    try {
      final manufacturer = await _channel.invokeMethod<String>(
        'getDeviceManufacturer',
      );
      setState(() {
        _manufacturer = manufacturer?.toLowerCase() ?? '';
      });
    } catch (e) {
      debugPrint('获取厂商信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('开启后台运行权限', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFirstTime) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '为确保全球发送能够在后台持续运行，请按以下步骤设置',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 步骤列表
              _buildStepItem(
                step: 1,
                title: '开启自启动权限',
                description: _getAutoStartDescription(),
                buttonText: '去设置',
                onTap: _openAutoStartSettings,
              ),
              const SizedBox(height: 12),

              _buildStepItem(
                step: 2,
                title: '关闭电池优化',
                description: '将本应用设为"不优化"或"无限制"',
                buttonText: '去设置',
                onTap: _openBatteryOptimization,
              ),
              const SizedBox(height: 12),

              _buildStepItem(
                step: 3,
                title: '锁定应用（可选）',
                description: '在最近任务中锁定应用，防止被清理',
                buttonText: null,
                onTap: null,
              ),

              const SizedBox(height: 16),

              // 提示信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '不同品牌手机设置位置可能不同，如找不到选项请在设置中搜索"自启动"或"后台运行"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            widget.isFirstTime ? '稍后设置' : '关闭',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('我已设置完成'),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required int step,
    required String title,
    required String description,
    String? buttonText,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isCompleted = _currentStep >= step;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (buttonText != null && onTap != null)
            TextButton(
              onPressed: () {
                onTap();
                setState(() {
                  if (_currentStep < step) {
                    _currentStep = step;
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  String _getAutoStartDescription() {
    if (_manufacturer.contains('xiaomi') || _manufacturer.contains('redmi')) {
      return '在MIUI安全中心中开启本应用的自启动权限';
    } else if (_manufacturer.contains('huawei') ||
        _manufacturer.contains('honor')) {
      return '在手机管家-应用启动管理中设置为手动管理';
    } else if (_manufacturer.contains('oppo') ||
        _manufacturer.contains('realme')) {
      return '在手机管家-自启动管理中开启本应用';
    } else if (_manufacturer.contains('vivo')) {
      return '在i管家-后台管理中允许本应用后台运行';
    } else if (_manufacturer.contains('samsung')) {
      return '在设备维护-电池-未监控的应用中添加本应用';
    } else {
      return '在系统设置中允许本应用自启动';
    }
  }

  Future<void> _openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      debugPrint('打开自启动设置失败: $e');
      _showErrorSnackBar('无法打开设置，请手动前往设置页面');
    }
  }

  Future<void> _openBatteryOptimization() async {
    try {
      await _channel.invokeMethod('openBatteryOptimization');
    } catch (e) {
      debugPrint('打开电池优化设置失败: $e');
      _showErrorSnackBar('无法打开设置，请手动前往设置页面');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
