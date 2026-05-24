import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/practice_book_model.dart';
import '../services/offline_asr_model_service.dart';
import '../services/practice_book_service.dart';

class PracticeBookSheet extends StatefulWidget {
  final String practiceTitle;
  final void Function(PracticeBook? book)? onChanged;

  const PracticeBookSheet({
    super.key,
    required this.practiceTitle,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String practiceTitle,
    void Function(PracticeBook? book)? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          PracticeBookSheet(practiceTitle: practiceTitle, onChanged: onChanged),
    );
  }

  @override
  State<PracticeBookSheet> createState() => _PracticeBookSheetState();
}

class _PracticeBookSheetState extends State<PracticeBookSheet> {
  final _service = PracticeBookService.instance;
  final _modelService = OfflineAsrModelService.instance;
  PracticeBook? _book;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
    _modelService.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _modelService.removeListener(_onModelChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final book = await _service.getActiveBook(widget.practiceTitle);
    await _modelService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _book = book;
      _loading = false;
    });
  }

  void _onModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'docx', 'pdf'],
      );
      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;
      final file = files.first;
      final importResult = await _service.importFile(
        file: file,
        practiceTitle: widget.practiceTitle,
      );
      await _handleImportResult(importResult);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inputUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('导入链接', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '粘贴微信公众号或网页链接',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _service.importUrl(
        url: url,
        practiceTitle: widget.practiceTitle,
      );
      if (!result.isSuccess && result.needsWebViewFallback && mounted) {
        final book = await Navigator.push<PracticeBook>(
          context,
          MaterialPageRoute(
            builder: (_) => PracticeBookWebImportScreen(
              practiceTitle: widget.practiceTitle,
              sourceUrl: url,
            ),
          ),
        );
        if (book != null) {
          await _setBook(book, '已从页面提取功课本');
          return;
        }
      }
      await _handleImportResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleImportResult(PracticeBookImportResult result) async {
    if (result.book != null) {
      await _setBook(result.book!, '功课本已保存');
    } else if (mounted) {
      setState(() => _message = result.error ?? '导入失败');
    }
  }

  Future<void> _setBook(PracticeBook book, String message) async {
    if (!mounted) return;
    setState(() {
      _book = book;
      _message = message;
    });
    widget.onChanged?.call(book);
  }

  Future<void> _downloadModel() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final path = await _modelService.downloadModel();
      if (!mounted) return;
      setState(() {
        _message = path == null ? _modelService.statusMessage : '离线语音模型已就绪';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBook() async {
    final book = _book;
    if (book == null) return;
    setState(() => _busy = true);
    try {
      await _service.deleteBook(book.id);
      if (!mounted) return;
      setState(() {
        _book = null;
        _message = '功课本已删除';
      });
      widget.onChanged?.call(null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelReady = _modelService.status == OfflineAsrModelStatus.installed;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.practiceTitle,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildCurrentBook(),
                  const SizedBox(height: 14),
                  _buildModelStatus(modelReady),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.upload_file,
                          label: '文件',
                          enabled: !_busy,
                          onTap: _pickFile,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.link,
                          label: '链接',
                          enabled: !_busy,
                          onTap: _inputUrl,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: modelReady ? Icons.check_circle : Icons.mic,
                          label: modelReady ? '已就绪' : '模型',
                          enabled: !_busy && !modelReady,
                          onTap: _downloadModel,
                        ),
                      ),
                    ],
                  ),
                  if (_book != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _busy ? null : _deleteBook,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除当前功课本'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCurrentBook() {
    final book = _book;
    if (book == null) {
      return const Text(
        '尚未添加功课本。添加后，禅室会用本地语音识别自动判断念诵遍数。',
        style: TextStyle(color: Colors.white70, height: 1.5),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${book.normalizedText.length} 字 · ${_syncLabel(book.syncStatus)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildModelStatus(bool modelReady) {
    final progress = _modelService.progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: modelReady
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: modelReady
              ? Colors.green.withValues(alpha: 0.35)
              : Colors.orange.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                modelReady ? Icons.offline_bolt : Icons.download,
                color: modelReady ? Colors.greenAccent : Colors.orangeAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _modelService.statusMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          if (_modelService.status == OfflineAsrModelStatus.downloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress <= 0 ? null : progress,
              color: const Color(0xFFD4AF37),
              backgroundColor: Colors.white12,
            ),
          ],
        ],
      ),
    );
  }

  String _syncLabel(PracticeBookSyncStatus status) {
    return switch (status) {
      PracticeBookSyncStatus.synced => '已云端同步',
      PracticeBookSyncStatus.pendingUpload => '待云端同步',
      PracticeBookSyncStatus.syncFailed => '云端同步失败',
      PracticeBookSyncStatus.localOnly => '仅本地',
    };
  }
}

class PracticeBookWebImportScreen extends StatefulWidget {
  final String practiceTitle;
  final String sourceUrl;

  const PracticeBookWebImportScreen({
    super.key,
    required this.practiceTitle,
    required this.sourceUrl,
  });

  @override
  State<PracticeBookWebImportScreen> createState() =>
      _PracticeBookWebImportScreenState();
}

class _PracticeBookWebImportScreenState
    extends State<PracticeBookWebImportScreen> {
  InAppWebViewController? _controller;
  bool _busy = false;

  Future<void> _extract() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _busy = true);
    try {
      final title = await controller.evaluateJavascript(
        source: 'document.title || ""',
      );
      final text = await controller.evaluateJavascript(
        source:
            'document.querySelector("#js_content")?.innerText || document.body.innerText || ""',
      );
      final plainText = text?.toString() ?? '';
      if (plainText.trim().length < 20) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未能从当前页面提取到足够正文')));
        }
        return;
      }
      final book = await PracticeBookService.instance.saveExtractedWebText(
        practiceTitle: widget.practiceTitle,
        sourceUrl: widget.sourceUrl,
        title: title?.toString() ?? '',
        plainText: plainText,
      );
      if (mounted) Navigator.pop(context, book);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提取功课本'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _extract,
            icon: const Icon(Icons.save_alt),
            label: const Text('提取'),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.sourceUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (controller) => _controller = controller,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 19),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
