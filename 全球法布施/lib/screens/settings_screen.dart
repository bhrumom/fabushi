import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testMode = false;
  String _backendUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final testMode = await AppSettings.getTestMode();
      final backendUrl = await AppSettings.getBackendUrl();
      
      setState(() {
        _testMode = testMode;
        _backendUrl = backendUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载设置失败: $e')),
        );
      }
    }
  }

  Future<void> _saveTestMode(bool value) async {
    try {
      await AppSettings.setTestMode(value);
      setState(() {
        _testMode = value;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '已切换到测试模式' : '已切换到真实后端'),
            backgroundColor: value ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败: $e')),
        );
      }
    }
  }

  Future<void> _saveBackendUrl(String url) async {
    try {
      await AppSettings.setBackendUrl(url);
      setState(() {
        _backendUrl = url;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('后端URL已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存URL失败: $e')),
        );
      }
    }
  }

  Future<void> _resetSettings() async {
    try {
      await AppSettings.resetToDefaults();
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已重置为默认值')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置设置失败: $e')),
        );
      }
    }
  }

  void _showUrlEditDialog() {
    final controller = TextEditingController(text: _backendUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑后端URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '后端URL',
            hintText: 'https://your-backend.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                _saveBackendUrl(url);
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用设置'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 模式设置
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _testMode ? Icons.bug_report : Icons.cloud,
                                    color: _testMode ? Colors.orange : Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '运行模式',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2c3e50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('测试模式'),
                                subtitle: Text(
                                  _testMode 
                                      ? '使用模拟数据，无需网络连接'
                                      : '连接到真实的Cloudflare后端',
                                ),
                                value: _testMode,
                                onChanged: _saveTestMode,
                                activeColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 后端设置
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.settings_ethernet,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '后端配置',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2c3e50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              ListTile(
                                title: const Text('当前后端URL'),
                                subtitle: Text(
                                  _backendUrl.isNotEmpty ? _backendUrl : '未设置',
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                                trailing: const Icon(Icons.edit),
                                onTap: _showUrlEditDialog,
                              ),
                              if (!_testMode) ...[
                                const Divider(),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.info, color: Colors.blue, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '当前使用真实后端，可以登录之前注册的账户',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 状态信息
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.purple,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '当前状态',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2c3e50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildStatusItem(
                                '运行模式',
                                _testMode ? '测试模式' : '生产模式',
                                _testMode ? Colors.orange : Colors.green,
                              ),
                              _buildStatusItem(
                                '后端地址',
                                _backendUrl,
                                Colors.blue,
                              ),
                              _buildStatusItem(
                                '数据来源',
                                _testMode ? '本地模拟数据' : 'Cloudflare后端',
                                _testMode ? Colors.orange : Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 操作按钮
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.build,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '操作',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2c3e50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _resetSettings,
                                  icon: const Icon(Icons.restore),
                                  label: const Text('重置为默认设置'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7f8c8d),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}