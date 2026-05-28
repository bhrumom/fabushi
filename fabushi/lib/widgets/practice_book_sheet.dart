import 'dart:io';

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
        allowedExtensions: [
          'txt',
          'md',
          'docx',
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
        ],
      );
      final files = result?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;
      final importResult = await _service.importFile(
        file: files.first,
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
        title: const Text('保存功课链接', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '粘贴网页或文章链接',
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
            child: const Text('保存'),
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
      await _handleImportResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inputText() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('输入功课文本', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '标题',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                minLines: 6,
                maxLines: 10,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '粘贴或输入要对着念的功课内容',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'text': textController.text.trim(),
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || (result['text'] ?? '').trim().isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final book = await _service.saveManualText(
        practiceTitle: widget.practiceTitle,
        title: result['title'] ?? '',
        plainText: result['text'] ?? '',
      );
      await _setBook(book, '功课本已保存到本机');
    } catch (e) {
      if (mounted) setState(() => _message = '保存失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleImportResult(PracticeBookImportResult result) async {
    if (result.book != null) {
      await _setBook(result.book!, '功课本已保存到本机');
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
      final modelPath = await _modelService.downloadModel();
      if (!mounted) return;
      setState(() {
        _message = modelPath == null
            ? _modelService.statusMessage
            : '离线语音模型已就绪';
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
        _message = '功课本已从本机删除';
      });
      widget.onChanged?.call(null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openReader() {
    final book = _book;
    if (book == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PracticeBookReaderScreen(book: book)),
    );
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionButton(
                        icon: Icons.upload_file,
                        label: '文件/图片',
                        enabled: !_busy,
                        onTap: _pickFile,
                      ),
                      _ActionButton(
                        icon: Icons.link,
                        label: '链接',
                        enabled: !_busy,
                        onTap: _inputUrl,
                      ),
                      _ActionButton(
                        icon: Icons.edit_note,
                        label: '文本',
                        enabled: !_busy,
                        onTap: _inputText,
                      ),
                      _ActionButton(
                        icon: modelReady ? Icons.check_circle : Icons.mic,
                        label: modelReady ? '模型就绪' : '语音模型',
                        enabled: !_busy && !modelReady,
                        onTap: _downloadModel,
                      ),
                    ],
                  ),
                  if (_book != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _openReader,
                            icon: const Icon(Icons.menu_book),
                            label: const Text('打开对着念'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _busy ? null : _deleteBook,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ],
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
        '尚未添加功课本。可保存链接、输入文本，或选择本机文件/图片；内容只保存在本机。',
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
            '${_sourceLabel(book.sourceType)} · ${_syncLabel(book.syncStatus)}',
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

  String _sourceLabel(PracticeBookSourceType type) {
    return switch (type) {
      PracticeBookSourceType.file => '本机文件',
      PracticeBookSourceType.url => '链接',
      PracticeBookSourceType.manual => '手输文本',
      PracticeBookSourceType.image => '图片',
      PracticeBookSourceType.cloud => '云端记录',
    };
  }

  String _syncLabel(PracticeBookSyncStatus status) {
    return switch (status) {
      PracticeBookSyncStatus.synced => '仅本机',
      PracticeBookSyncStatus.pendingUpload => '仅本机',
      PracticeBookSyncStatus.syncFailed => '仅本机',
      PracticeBookSyncStatus.localOnly => '仅本机',
    };
  }
}

class PracticeBookReaderScreen extends StatelessWidget {
  final PracticeBook book;

  const PracticeBookReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text(book.title),
        backgroundColor: const Color(0xFF151515),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (book.sourceType == PracticeBookSourceType.url &&
        (book.sourceUrl ?? '').isNotEmpty) {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(book.sourceUrl!)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
      );
    }

    if (book.sourceType == PracticeBookSourceType.image &&
        (book.sourceFilePath ?? '').isNotEmpty) {
      return InteractiveViewer(
        minScale: 0.6,
        maxScale: 5,
        child: Center(
          child: Image.file(
            File(book.sourceFilePath!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Text('图片文件不存在', style: TextStyle(color: Colors.white70)),
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 40),
        child: SelectableText(
          book.plainText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1.75,
            fontFamily: 'NotoSerifSC',
          ),
        ),
      ),
    );
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
    return SizedBox(
      width: 104,
      height: 50,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}
