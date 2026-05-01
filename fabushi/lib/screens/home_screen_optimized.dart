import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../models/auth_model.dart';
import 'settings_screen.dart';
import 'douyin_login_screen.dart';
import 'profile_screen.dart';
import '../widgets/enhanced_transfer_stats.dart';
import '../widgets/transfer_mode_selector.dart';
import 'global_dharma_screen.dart';
import '../widgets/common_widgets.dart';

/// 优化的首页 - 极致性能版本
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  IconData _getIconForFileType(String fileType) {
    switch (fileType) {
      case '图片':
        return Icons.image;
      case '文档':
        return Icons.article;
      case '音频':
        return Icons.audiotrack;
      case '视频':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🙏 大乘'),
        actions: [
          // 性能优化：只监听认证状态
          Selector<AuthModel, bool>(
            selector: (_, auth) => auth.isLoggedIn,
            builder: (context, isLoggedIn, _) {
              if (isLoggedIn) {
                return _buildUserMenu(context);
              } else {
                return IconButton(
                  icon: const Icon(Icons.login),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DouyinLoginScreen(),
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
                _buildMainCard(context),
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

  Widget _buildUserMenu(BuildContext context) {
    return Selector<AuthModel, String>(
      selector: (_, auth) => auth.currentUser?.username ?? '?',
      builder: (context, username, _) {
        return PopupMenuButton<String>(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                context.read<AuthModel>().logout();
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
                  Text(
                    '个人中心 (${context.read<AuthModel>().getMembershipStatusText()})',
                  ),
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
      },
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '大乘',
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
          _buildFileButtons(context),
          const SizedBox(height: 16),
          _buildFileList(),
          const SizedBox(height: 24),
          _buildStartButton(context),
        ],
      ),
    );
  }

  Widget _buildFileButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            text: '选择文件',
            icon: Icons.file_upload,
            onPressed: () => context.read<FileTransferModel>().selectFiles(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SecondaryButton(
            text: '内置素材',
            icon: Icons.image,
            onPressed: () =>
                context.read<FileTransferModel>().selectBuiltInAssets(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFileList() {
    // 性能优化：只监听文件列表变化
    return Selector<FileTransferModel, List<dynamic>>(
      selector: (_, model) => [model.selectedFiles, model.hasFiles],
      builder: (context, data, _) {
        final model = context.read<FileTransferModel>();
        final hasFiles = data[1] as bool;

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已选文件', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: hasFiles
                      ? ListView.builder(
                          itemCount: model.selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = model.selectedFiles[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                _getIconForFileType(
                                  model.getFileType(file.name),
                                ),
                                size: 20,
                              ),
                              title: Text(
                                file.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                model.getFileSizeString(file.size),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () => model.removeFile(file),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '请选择要发送的文件',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
                if (hasFiles) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.clear_all,
                        color: Colors.red,
                        size: 16,
                      ),
                      label: const Text(
                        '清空',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      onPressed: () => model.clearFiles(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartButton(BuildContext context) {
    // 性能优化：只监听hasFiles状态
    return Selector<FileTransferModel, bool>(
      selector: (_, model) => model.hasFiles,
      builder: (context, hasFiles, _) {
        return SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: '开始大乘',
            icon: Icons.public,
            onPressed: hasFiles
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GlobalDharmaScreen(),
                      ),
                    );
                  }
                : null,
          ),
        );
      },
    );
  }
}
