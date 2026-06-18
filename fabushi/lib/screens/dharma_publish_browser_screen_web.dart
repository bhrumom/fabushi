import 'package:flutter/material.dart';

import '../services/dharma_publish_service.dart';

class DharmaPublishBrowserScreen extends StatelessWidget {
  final DharmaPublishDraft draft;
  final List<DharmaPublishPlatform> platforms;

  const DharmaPublishBrowserScreen({
    super.key,
    required this.draft,
    required this.platforms,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      appBar: AppBar(title: const Text('发布工作台')),
      body: const Center(
        child: Text(
          'Web 端使用外部平台入口发布，请在首页继续操作。',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
