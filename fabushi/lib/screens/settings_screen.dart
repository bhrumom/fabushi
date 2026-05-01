import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'keep_alive_guide_screen.dart';
import '../services/app_settings.dart';
import '../services/llm_model_config.dart';
import '../services/llm_model_manager.dart';
import '../services/device_capability_service.dart';
import '../widgets/model_selection_dialog.dart';
import '../models/auth_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _defaultTtsMuted = true;
  bool _isLoading = true;

  // 读诵匹配阈值（百分比形式，0.0 ~ 1.0）
  double _fastMatchThreshold = 0.50;
  double _matchThreshold = 0.50;

  // AI 模型设置
  DeviceCapabilityInfo? _deviceInfo;
  LLMModelType? _selectedModel;
  Map<LLMModelType, ModelStatus>? _modelStatus;

  // 下载进度状态
  StreamSubscription<DownloadProgressEvent>? _downloadProgressSubscription;
  double _downloadProgress = 0.0;
  String _downloadStage = '';
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _subscribeToDownloadProgress();
  }

  @override
  void dispose() {
    _downloadProgressSubscription?.cancel();
    super.dispose();
  }

  /// 订阅下载进度流
  void _subscribeToDownloadProgress() {
    // 检查是否有正在进行的下载
    if (LLMModelManager.instance.isDownloading) {
      _isDownloading = true;
      _downloadProgress = LLMModelManager.instance.currentDownloadProgress;
      _downloadStage = LLMModelManager.instance.currentDownloadStage;
    }

    _downloadProgressSubscription = LLMModelManager
        .instance
        .downloadProgressStream
        .listen((event) {
          if (mounted) {
            setState(() {
              _isDownloading = !event.isComplete;
              _downloadProgress = event.progress;
              _downloadStage = event.stage;
            });

            // 下载完成时刷新模型状态
            if (event.isComplete) {
              _refreshModelStatus();
            }
          }
        });
  }

  /// 刷新模型状态
  Future<void> _refreshModelStatus() async {
    final newStatus = await LLMModelManager.instance.getAllModelStatus();
    if (mounted) {
      setState(() {
        _modelStatus = newStatus;
      });
    }
  }

  Future<void> _loadSettings() async {
    final defaultMuted = await AppSettings.getDefaultTtsMuted();
    final fastMatchThreshold = await AppSettings.getFastMatchThreshold();
    final matchThreshold = await AppSettings.getMatchThreshold();

    // 加载 AI 模型相关设置
    final deviceInfo = await DeviceCapabilityService.instance
        .getDeviceCapabilityInfo();
    final modelStatus = await LLMModelManager.instance.getAllModelStatus();
    final savedModelName = await AppSettings.getSelectedModelName();
    LLMModelType? selectedModel;
    if (savedModelName != null) {
      try {
        selectedModel = LLMModelType.values.firstWhere(
          (t) => t.name == savedModelName,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _defaultTtsMuted = defaultMuted;
        _fastMatchThreshold = fastMatchThreshold;
        _matchThreshold = matchThreshold;
        _deviceInfo = deviceInfo;
        _modelStatus = modelStatus;
        _selectedModel = selectedModel;
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefaultTtsMuted(bool value) async {
    setState(() => _defaultTtsMuted = value);
    await AppSettings.setDefaultTtsMuted(value);
  }

  Future<void> _setFastMatchThreshold(double value) async {
    setState(() => _fastMatchThreshold = value);
    await AppSettings.setFastMatchThreshold(value);
  }

  Future<void> _setMatchThreshold(double value) async {
    setState(() => _matchThreshold = value);
    await AppSettings.setMatchThreshold(value);
  }

  /// 显示删除模型确认对话框
  Future<void> _showDeleteModelDialog() async {
    if (_selectedModel == null) return;

    final config = LLMModelConfig.getConfig(_selectedModel!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('删除模型', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除 ${config.displayName} 吗？\n\n删除后需要重新下载才能使用。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 执行删除
      await LLMModelManager.instance.deleteModel(_selectedModel!);

      // 刷新模型状态
      final newStatus = await LLMModelManager.instance.getAllModelStatus();
      if (mounted) {
        setState(() {
          _modelStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${config.displayName} 已删除'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
                  // TODO: 临时隐藏，后续需要再开启
                  // // AI 模型设置
                  // _buildModelSettingCard(),
                  //
                  // // TTS 默认静音设置
                  // _buildTtsMuteSettingItem(),
                  //
                  // // 读诵匹配阈值设置
                  // _buildRecitationThresholdSettings(),

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
                        MaterialPageRoute(
                          builder: (_) => const KeepAliveGuideScreen(),
                        ),
                      ),
                    ),

                  _buildSettingItem(
                    context,
                    icon: Icons.refresh,
                    iconColor: Colors.cyan,
                    title: '刷新数据',
                    subtitle: '重新同步账户信息',
                    onTap: () async {
                      final authModel = Provider.of<AuthModel>(
                        context,
                        listen: false,
                      );
                      await authModel.refreshUserInfo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('数据已刷新'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),

                  _buildSettingItem(
                    context,
                    icon: Icons.help_outline,
                    iconColor: Colors.orange,
                    title: '帮助与反馈',
                    subtitle: '联系邮箱: support@ombhrum.com',
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text(
                          '帮助与反馈',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          '如果您发现任何违规内容，或有任何建议，请联系我们：\n\n邮箱：support@ombhrum.com\n我们将会在24小时内处理您的反馈。',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
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
                      applicationName: '大乘',
                      applicationVersion: '1.0.0',
                      children: [const Text('传播佛法，利益众生')],
                    ),
                  ),

                  _buildDeleteAccountItem(context),

                  _buildLogoutItem(context),
                ],
              ),
            ),
    );
  }

  /// AI模型设置卡片
  Widget _buildModelSettingCard() {
    final LLMModelConfig? selectedConfig;
    final ModelStatus? selectedStatus;

    if (_selectedModel != null) {
      selectedConfig = LLMModelConfig.getConfig(_selectedModel!);
      selectedStatus = _modelStatus?[_selectedModel!];
    } else {
      selectedConfig = null;
      selectedStatus = null;
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 模型',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '用于语义分析和智能推理',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 设备信息提示
            if (_deviceInfo != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '内存 ${_deviceInfo!.ramString} | ${_deviceInfo!.levelString}设备',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 当前模型信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedModel == LLMModelType.deepseekR1
                        ? Icons.lightbulb
                        : Icons.memory,
                    color: selectedConfig != null ? Colors.amber : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedConfig?.displayName ?? '未选择模型',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (selectedConfig != null)
                          Text(
                            '${selectedConfig.sizeString} | ${selectedStatus == ModelStatus.downloaded ? "已下载" : "未下载"}',
                            style: TextStyle(
                              color: selectedStatus == ModelStatus.downloaded
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            '请选择一个 AI 模型',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 状态指示
                  if (selectedStatus == ModelStatus.downloaded)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  else if (selectedStatus == ModelStatus.downloading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    )
                  else
                    const Icon(Icons.download, color: Colors.orange, size: 20),
                ],
              ),
            ),

            // 下载进度显示（仅在下载中时显示）
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _downloadStage.isNotEmpty
                                ? _downloadStage
                                : '下载中...',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.amber,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 切换模型按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await ModelSelectionDialog.show(context);
                  if (result != null) {
                    setState(() {
                      _selectedModel = result;
                    });
                    // 刷新模型状态
                    final newStatus = await LLMModelManager.instance
                        .getAllModelStatus();
                    if (mounted) {
                      setState(() {
                        _modelStatus = newStatus;
                      });
                    }
                  }
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(_selectedModel == null ? '选择模型' : '切换模型'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // 删除模型按钮（仅当模型已下载时显示）
            if (_selectedModel != null &&
                selectedStatus == ModelStatus.downloaded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteModelDialog(),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除模型'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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

  /// 读诵匹配阈值设置
  Widget _buildRecitationThresholdSettings() {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '读诵识别灵敏度',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '调整智能识别的切换阈值',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 快速切换阈值
            Row(
              children: [
                const Text(
                  '快速切换',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_fastMatchThreshold * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: _fastMatchThreshold,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              activeColor: Colors.green,
              inactiveColor: Colors.green.withOpacity(0.3),
              onChanged: _setFastMatchThreshold,
            ),
            const Text(
              '匹配度达到此值时立即切换下一句',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: 16),

            // 普通匹配阈值
            Row(
              children: [
                const Text(
                  '普通匹配',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_matchThreshold * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: _matchThreshold,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              activeColor: Colors.amber,
              inactiveColor: Colors.amber.withOpacity(0.3),
              onChanged: _setMatchThreshold,
            ),
            const Text(
              '匹配度达到此值且检测到停顿时切换',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
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
              content: const Text(
                '确定要退出登录吗？',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '退出',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final authModel = Provider.of<AuthModel>(context, listen: false);
            await authModel.logout();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已退出登录')));
              Navigator.pop(context); // 返回上一页
            }
          }
        },
      ),
    );
  }

  /// 注销账户按钮
  Widget _buildDeleteAccountItem(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_remove, color: Colors.red, size: 24),
        ),
        title: const Text(
          '注销账户',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          '此操作不可逆，将永久删除您的数据',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '风险警告',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                '您正在申请注销账户。\n\n注销后，您的所有个人数据、记录与设置将被彻底删除，并且无法恢复。确定要继续吗？',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    '点错了，取消',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '确定注销',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            // 提供双重认证防止误操作
            if (!context.mounted) return;
            final doubleConfirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text(
                  '最终确认',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  '账户删除后将彻底丢失，不可找回，这是最后的确认，还要继续吗？',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '确认删除账户',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (doubleConfirm == true) {
              if (!context.mounted) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(child: CircularProgressIndicator());
                },
              );

              final authModel = Provider.of<AuthModel>(context, listen: false);
              final res = await authModel.deleteAccount();

              if (!context.mounted) return;
              Navigator.pop(context); // close loading indicator

              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('账户已成功注销'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // 返回上一页到未登录状态页面
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['error'] ?? '注销失败，请重试或联系客服'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
}
