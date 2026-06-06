import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/design_system/app_theme.dart';
import '../services/dharma_publish_service.dart';

class DharmaPublishBrowserScreen extends StatefulWidget {
  final DharmaPublishDraft draft;
  final List<DharmaPublishPlatform> platforms;

  const DharmaPublishBrowserScreen({
    super.key,
    required this.draft,
    required this.platforms,
  });

  @override
  State<DharmaPublishBrowserScreen> createState() =>
      _DharmaPublishBrowserScreenState();
}

class _DharmaPublishBrowserScreenState
    extends State<DharmaPublishBrowserScreen> {
  InAppWebViewController? _controller;
  int _currentIndex = 0;
  bool _loading = true;
  bool _runningScript = false;
  final Map<DharmaPublishPlatform, List<String>> _steps = {};
  final Set<DharmaPublishPlatform> _completed = {};

  DharmaPublishPlatform get _currentPlatform => widget.platforms[_currentIndex];

  @override
  void initState() {
    super.initState();
    for (final platform in widget.platforms) {
      _steps[platform] = <String>[
        '已创建发布任务：${platform.info.label}',
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _copyDraftToClipboard();
    });
  }

  Future<void> _copyDraftToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.draft.fullText));
    _addStep(_currentPlatform, '已把完整草稿复制到剪贴板，可随时粘贴。');
  }

  void _addStep(DharmaPublishPlatform platform, String message) {
    if (!mounted) return;
    setState(() {
      _steps.putIfAbsent(platform, () => <String>[]).add(message);
    });
  }

  Future<void> _runAutofill() async {
    final controller = _controller;
    if (controller == null || _runningScript) return;
    setState(() => _runningScript = true);
    final platform = _currentPlatform;
    try {
      await _copyDraftToClipboard();
      final payload = jsonEncode({
        'title': widget.draft.title,
        'body': widget.draft.body,
        'sourceUrl': widget.draft.sourceUrl,
        'tags': widget.draft.tags.map((tag) => '#$tag').join(' '),
        'fullText': widget.draft.fullText,
      });
      final result = await controller.evaluateJavascript(
        source: _autofillScript(payload),
      );
      final text = result?.toString() ?? '';
      _addStep(
        platform,
        text.isEmpty ? '已执行页面自动填充脚本。' : '页面自动填充结果：$text',
      );
      _addStep(platform, '请在页面中检查标题、正文和附件，再点击平台自己的发布/保存按钮。');
    } catch (e) {
      _addStep(platform, '自动填充脚本执行失败：$e');
    } finally {
      if (mounted) setState(() => _runningScript = false);
    }
  }

  String _autofillScript(String payloadJson) {
    return '''
(() => {
  const payload = $payloadJson;
  const visible = (el) => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style && style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const textInputs = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"], [role="textbox"]'))
    .filter(visible);
  const fire = (el) => {
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
  };
  const labelOf = (el) => [
    el.getAttribute('placeholder') || '',
    el.getAttribute('aria-label') || '',
    el.getAttribute('name') || '',
    el.id || '',
    el.className || '',
    el.parentElement?.innerText?.slice(0, 60) || ''
  ].join(' ').toLowerCase();
  const setValue = (el, value) => {
    if (!el || !value) return false;
    el.focus();
    if (el.isContentEditable || el.getAttribute('contenteditable') === 'true' || el.getAttribute('role') === 'textbox') {
      el.innerText = value;
    } else {
      el.value = value;
    }
    fire(el);
    return true;
  };
  const titleInput = textInputs.find((el) => /title|标题|题目|headline|subject/.test(labelOf(el))) || textInputs.find((el) => el.tagName === 'INPUT');
  const bodyInput = textInputs.find((el) => /content|正文|内容|描述|介绍|article|editor|文本/.test(labelOf(el)))
    || textInputs.filter((el) => el !== titleInput).sort((a, b) => (b.getBoundingClientRect().height || 0) - (a.getBoundingClientRect().height || 0))[0]
    || textInputs.find((el) => el !== titleInput);
  const titleOk = setValue(titleInput, payload.title);
  const bodyText = [payload.body, payload.sourceUrl ? '来源链接：' + payload.sourceUrl : '', payload.tags].filter(Boolean).join('\n\n');
  const bodyOk = setValue(bodyInput, bodyText || payload.fullText);
  return JSON.stringify({ titleFilled: titleOk, bodyFilled: bodyOk, editableCount: textInputs.length, pageTitle: document.title });
})();
''';
  }

  List<DharmaPublishResult> _buildResults({required bool finished}) {
    return widget.platforms.map((platform) {
      final steps = List<String>.from(_steps[platform] ?? const <String>[]);
      final success = finished || _completed.contains(platform);
      return DharmaPublishResult(
        platform: platform,
        success: success,
        message: success
            ? '已在内置浏览器打开 ${platform.info.label} 并准备草稿'
            : '已记录 ${platform.info.label} 的浏览器步骤，尚未标记完成',
        steps: steps,
      );
    }).toList();
  }

  Future<void> _markCurrentDone() async {
    final platform = _currentPlatform;
    _addStep(platform, '用户已确认此平台页面处理完成。');
    setState(() => _completed.add(platform));
    if (_currentIndex < widget.platforms.length - 1) {
      setState(() {
        _currentIndex += 1;
        _loading = true;
      });
      await _controller?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(widget.platforms[_currentIndex].info.desktopUrl),
        ),
      );
      await _copyDraftToClipboard();
    } else if (mounted) {
      Navigator.pop(context, _buildResults(finished: true));
    }
  }

  Future<void> _finishAll() async {
    if (!mounted) return;
    Navigator.pop(context, _buildResults(finished: true));
  }

  @override
  Widget build(BuildContext context) {
    final platform = _currentPlatform;
    final steps = _steps[platform] ?? const <String>[];
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: Text('法布施到平台：${platform.info.label}'),
        backgroundColor: const Color(0xFF151515),
        actions: [
          TextButton.icon(
            onPressed: _runningScript ? null : _runAutofill,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(_runningScript ? '填充中' : '填充草稿'),
          ),
          TextButton.icon(
            onPressed: _markCurrentDone,
            icon: const Icon(Icons.done),
            label: Text(_currentIndex < widget.platforms.length - 1 ? '下一平台' : '完成'),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 330,
            child: Container(
              color: const Color(0xFF181818),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '发布草稿',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.draft.fullText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '平台进度',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < widget.platforms.length; i++)
                      _BrowserPlatformTile(
                        platform: widget.platforms[i],
                        selected: i == _currentIndex,
                        done: _completed.contains(widget.platforms[i]),
                        onTap: () async {
                          setState(() {
                            _currentIndex = i;
                            _loading = true;
                          });
                          await _controller?.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(widget.platforms[i].info.desktopUrl),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 18),
                    ExpansionTile(
                      initiallyExpanded: true,
                      collapsedIconColor: Colors.white70,
                      iconColor: AppTheme.primaryColor,
                      title: const Text(
                        '当前步骤',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      children: [
                        for (final step in steps)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white54,
                              size: 18,
                            ),
                            title: Text(
                              step,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _finishAll,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('汇总返回对话'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(platform.info.desktopUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() => _loading = true);
                    _addStep(platform, '打开页面：${url?.toString() ?? platform.info.desktopUrl}');
                  },
                  onLoadStop: (controller, url) async {
                    setState(() => _loading = false);
                    _addStep(platform, '页面加载完成：${url?.toString() ?? ''}');
                    await _runAutofill();
                  },
                  onReceivedError: (controller, request, error) {
                    _addStep(platform, '页面加载错误：${error.description}');
                  },
                ),
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserPlatformTile extends StatelessWidget {
  final DharmaPublishPlatform platform;
  final bool selected;
  final bool done;
  final VoidCallback onTap;

  const _BrowserPlatformTile({
    required this.platform,
    required this.selected,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppTheme.primaryColor : Colors.white54,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  platform.info.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
