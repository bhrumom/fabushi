import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/file_transfer_model.dart';
import '../models/auth_model.dart';
import 'settings_screen.dart';
import 'p2p_demo_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../widgets/file_selection_card.dart';
import '../widgets/enhanced_transfer_stats.dart';
import '../widgets/transfer_mode_selector.dart';
import '../services/no_connection_service.dart';
import 'no_connection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  /// 开始无连接传输
  void _startNoConnectionTransfer(BuildContext context, FileTransferModel model) async {
    try {
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🙏 全球法布施'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('全球法布施特点：'),
              SizedBox(height: 8),
              Text('✅ 将法布施内容发送到全球网络'),
              Text('✅ 无需建立连接，立即发送'),
              Text('✅ 使用多种网络协议确保送达'),
              Text('✅ 利益众生，功德无量'),
              SizedBox(height: 16),
              Text(
                '💫 此功能将您的法布施内容传播到全世界',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('开始全球法布施'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 创建无连接服务
      final noConnectionService = NoConnectionService(
        onProgress: (count) {
          model.updateProgress(count);
        },
        onDataSent: (dataMB) {
          model.updateDataSent(dataMB);
        },
        onStopped: () {
          model.stopTransfer();
        },
      );

      // 更新状态为传输中
      model.updateStatus(TransferStatus.transferring);

      // 显示进度提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🙏 全球法布施已启动，正在将法布施内容传播到全世界...'),
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 3),
        ),
      );

      // 开始无连接发送
      await noConnectionService.startSending(
        files: model.selectedFiles,
        isWeb: kIsWeb,
        isLoop: false, // 默认不循环
        country: 'ALL', // 发送到所有国家
      );

    } catch (e) {
      // 错误处理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 全球法布施失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
      model.stopTransfer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🙏 全球法布施'),
        centerTitle: true,
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          // 用户头像/登录按钮
          Consumer<AuthModel>(
            builder: (context, authModel, child) {
              if (authModel.isLoggedIn) {
                return PopupMenuButton<String>(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        authModel.currentUser!.username.isNotEmpty
                            ? authModel.currentUser!.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                        break;
                      case 'logout':
                        authModel.logout();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person),
                          const SizedBox(width: 8),
                          Text('个人中心 (${authModel.getMembershipStatusText()})'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('登出', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.login),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  tooltip: '登录',
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文件选择区域
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择文件',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.read<FileTransferModel>().selectFiles(),
                                icon: const Icon(Icons.file_upload),
                                label: const Text('选择文件'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.read<FileTransferModel>().selectBuiltInAssets(),
                                icon: const Icon(Icons.image),
                                label: const Text('内置素材'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Consumer<FileTransferModel>(
                          builder: (context, model, child) {
                            if (model.selectedFiles.isEmpty) {
                              return const Text('未选择文件');
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('已选择 ${model.selectedFiles.length} 个文件'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: model.status == TransferStatus.transferring 
                                      ? null 
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const NoConnectionScreen(),
                                          ),
                                        ),
                                    icon: const Icon(Icons.favorite, color: Colors.white),
                                    label: const Text('全球法布施', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '🙏 全球法布施：将法布施内容发送到全球网络，利益众生',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.deepOrange,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const EnhancedTransferStats(),
                const SizedBox(height: 16),
                const TransferModeSelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}