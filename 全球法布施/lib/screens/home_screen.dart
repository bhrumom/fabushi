import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/file_transfer_model.dart';
import '../models/auth_model.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../widgets/file_selection_card.dart';
import '../widgets/enhanced_transfer_stats.dart';
import '../widgets/transfer_mode_selector.dart';

import 'asset_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

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
                // 全球法布施功能入口
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '全球法布施',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '将佛法宝藏传播到世界每一个角落，利益一切有情众生。此功能提供高级选项，允许您选择素材、调整并发数并监控实时进度。',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
                                onPressed: () => context.read<FileTransferModel>().selectBuiltInAssets(context),
                                icon: const Icon(Icons.image),
                                label: const Text('内置素材'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Consumer<FileTransferModel>(
                          builder: (context, model, child) {
                            return ElevatedButton.icon(
                              onPressed: model.hasFiles ? () => model.startGlobalTransfer() : null,
                              icon: const Icon(Icons.public, color: Colors.white),
                              label: const Text('开始全球法布施', style: TextStyle(fontSize: 18)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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