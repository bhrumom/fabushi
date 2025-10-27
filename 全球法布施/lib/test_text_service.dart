import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';

class TestTextServiceScreen extends StatefulWidget {
  const TestTextServiceScreen({super.key});

  @override
  State<TestTextServiceScreen> createState() => _TestTextServiceScreenState();
}

class _TestTextServiceScreenState extends State<TestTextServiceScreen> {
  final _textService = CloudflareTextService();
  String _status = '点击按钮测试文本服务';
  bool _isLoading = false;

  Future<void> _testService() async {
    setState(() {
      _isLoading = true;
      _status = '正在测试...';
    });

    try {
      final textData = await _textService.getRandomTextContent();
      if (textData != null) {
        setState(() {
          _status = '✅ 成功!\n\n'
              '标题: ${textData['title']}\n'
              '内容长度: ${textData['content']?.length ?? 0} 字符\n'
              '文件路径: ${textData['filePath']}\n\n'
              '内容预览:\n${textData['content']?.substring(0, 200) ?? ''}...';
        });
      } else {
        setState(() {
          _status = '❌ 失败: 无法获取文本内容';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ 错误: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试文本服务'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testService,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('测试文本服务'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
