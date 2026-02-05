import 'package:flutter/material.dart';
import '../services/cloudflare_text_service.dart';
import '../features/video_feed/presentation/view/widgets/video_feed_view_full_text_reader.dart';

/// 经文阅读界面
/// 
/// 用于禅室中点击经书后打开的全文阅读界面
/// 复用法流页面的 VideoFeedViewFullTextReader 组件

/// 打开经文阅读界面
Future<void> openSutraReader(
  BuildContext context, {
  required String title,
  required String filePath,
}) async {
  final textService = CloudflareTextService();
  String? content;

  // 显示加载指示器
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        color: Color(0xFF1E1E1E),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD4AF37)),
              SizedBox(height: 16),
              Text('正在加载经文...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // 尝试通过 filePath 加载
    if (filePath.isNotEmpty && !filePath.startsWith('sample_')) {
      final result = await textService.getTextByFilePath(filePath);
      if (result != null && result['content'] != null) {
        content = result['content'] as String;
      }
    }

    // 如果加载失败，尝试从内置样本获取
    if (content == null) {
      final allTexts = await textService.getAllTexts();
      final matchedText = allTexts.firstWhere(
        (t) => t['title'] == title,
        orElse: () => <String, String>{},
      );

      if (matchedText.isNotEmpty && matchedText['content'] != null) {
        content = matchedText['content'];
      }
    }

    // 关闭加载指示器
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (content == null || content.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法加载经文内容'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 打开全文阅读器
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoFeedViewFullTextReader(
            bookTitle: title,
            fullText: content!,
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('加载经文失败: $e');
    // 关闭加载指示器
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
