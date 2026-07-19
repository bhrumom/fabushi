import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import '../services/codex_plugin_catalog.dart';
import '../services/mahayana_sdk.dart';
import '../services/miniapp/host_capability_bridge.dart';
import '../widgets/mcp_schema_form_dialog.dart';
import '../widgets/social/social_feature_bot.dart';

typedef MiniAppHostEventCallback = void Function(Map<String, dynamic> event);

class MiniAppHostCommand {
  MiniAppHostCommand({
    required this.text,
    String? commandId,
    String? command,
    String? args,
    this.background = true,
    DateTime? createdAt,
  }) : commandId = commandId ?? 'mcp_${DateTime.now().microsecondsSinceEpoch}',
       command = command ?? _commandFor(text),
       args = args ?? _argsFor(text),
       createdAt = createdAt ?? DateTime.now();

  final String commandId;
  final String text;
  final String command;
  final String args;
  final bool background;
  final DateTime createdAt;

  static String _commandFor(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('/')) return '';
    final split = trimmed.indexOf(RegExp(r'\s'));
    return (split < 0 ? trimmed : trimmed.substring(0, split)).substring(1);
  }

  static String _argsFor(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('/')) return trimmed;
    final split = trimmed.indexOf(RegExp(r'\s'));
    return split < 0 ? '' : trimmed.substring(split + 1);
  }
}

class MiniAppHostController {
  _MiniAppHostScreenState? _state;
  Completer<_MiniAppHostScreenState> _attached =
      Completer<_MiniAppHostScreenState>();

  bool get isAttached => _state != null;

  void _attach(_MiniAppHostScreenState state) {
    _state = state;
    if (!_attached.isCompleted) _attached.complete(state);
  }

  void _detach(_MiniAppHostScreenState state) {
    if (!identical(_state, state)) return;
    _state = null;
    _attached = Completer<_MiniAppHostScreenState>();
  }

  Future<Map<String, dynamic>> runCommand(
    String text, {
    String? command,
    String? args,
    String? commandId,
    bool background = true,
  }) async {
    final state = await _waitForAttached();
    return state._runCommand(
      MiniAppHostCommand(
        text: text,
        command: command,
        args: args,
        commandId: commandId,
        background: background,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getCommands() async {
    final state = await _waitForAttached();
    await state._ready.future.timeout(const Duration(seconds: 20));
    return state._commands;
  }

  Future<Map<String, dynamic>> getComposerState() async {
    final state = await _waitForAttached();
    await state._ready.future.timeout(const Duration(seconds: 20));
    return {'commands': state._commands, 'placeholder': '输入 / 查看 MCP Tools'};
  }

  Future<_MiniAppHostScreenState> _waitForAttached() async {
    return _state ??
        _attached.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw const MiniAppHostException(
            'host_not_ready',
            'MCP App Host 尚未挂载',
          ),
        );
  }
}

class MiniAppHostScreen extends StatefulWidget {
  const MiniAppHostScreen({
    super.key,
    required this.bot,
    this.inline = false,
    this.headless = false,
    this.onMinimize,
    this.onClose,
    this.startParam,
    this.controller,
    this.onMiniAppEvent,
    this.onCliStart,
    this.onCliLog,
    this.reloadToken,
    this.authToken,
  });

  final SocialFeatureBot bot;
  final bool inline;
  final bool headless;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final String? startParam;
  final MiniAppHostController? controller;
  final MiniAppHostEventCallback? onMiniAppEvent;
  final void Function(String title, String taskId)? onCliStart;
  final void Function(String taskId, String data)? onCliLog;
  final String? reloadToken;
  final String? authToken;

  @override
  State<MiniAppHostScreen> createState() => _MiniAppHostScreenState();
}

class _MiniAppHostScreenState extends State<MiniAppHostScreen> {
  static const _capabilityBridge = MiniAppHostCapabilityBridge();
  Completer<void> _ready = Completer<void>();
  InAppWebViewController? _webView;
  List<Map<String, dynamic>> _tools = const [];
  String? _conversationId;
  String? _uiHtml;
  CodexPluginDescriptor? _pluginPackage;
  String? _error;

  bool get _usesEmbeddedPluginRuntime =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  String get _pluginId {
    final id = widget.bot.stableMiniAppId.replaceFirst(
      RegExp(r'^official\.'),
      '',
    );
    return switch (id) {
      'flashcards' => 'faliu-flashcards',
      'assistant' => 'mahayana-assistant',
      _ => id,
    };
  }

  List<Map<String, dynamic>> get _commands => _tools
      .map(
        (tool) => {
          'command': '/${tool['name']}',
          'name': tool['name'],
          'description': tool['description'] ?? '',
          'inputSchema': tool['inputSchema'] ?? const <String, dynamic>{},
          'annotations': tool['annotations'] ?? const <String, dynamic>{},
        },
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant MiniAppHostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.bot.stableMiniAppId != widget.bot.stableMiniAppId ||
        oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.authToken != widget.authToken) {
      _conversationId = null;
      _ready = Completer<void>();
      _tools = const [];
      _uiHtml = null;
      _pluginPackage = null;
      _error = null;
      unawaited(_initialize());
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      CodexPluginDescriptor? pluginPackage;
      if (!_usesEmbeddedPluginRuntime) {
        pluginPackage = await CodexPluginCatalogService.instance.findPlugin(
          _pluginId,
          forceRefresh: true,
        );
      }
      try {
        await _refreshTools();
      } catch (_) {
        if (pluginPackage == null) rethrow;
        _tools = const [];
      }
      if (!mounted) return;
      var html = pluginPackage?.hasUi == true
          ? pluginPackage!.uiHtml!
          : _pluginFolderHtml(pluginPackage);
      try {
        final ui = await MahayanaSdk.instance.execute({
          '@type': 'mahayana.plugin.ui',
          'pluginId': _pluginId,
        });
        final runtimeHtml = ui['html']?.toString().trim();
        if (runtimeHtml?.isNotEmpty == true) html = runtimeHtml!;
      } catch (_) {
        if (_usesEmbeddedPluginRuntime) rethrow;
      }
      setState(() {
        _pluginPackage = pluginPackage;
        _uiHtml = html;
      });
      if (!_ready.isCompleted) _ready.complete();
    } catch (error, stack) {
      if (!_ready.isCompleted) _ready.completeError(error, stack);
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _refreshTools() async {
    final listed = await MahayanaSdk.instance.execute({
      '@type': 'mahayana.plugin.commands',
      'pluginId': _pluginId,
    });
    final raw = listed['data'] is List ? listed['data'] as List : const [];
    _tools = raw
        .whereType<Map>()
        .map((descriptor) {
          final command = descriptor['command']?.toString() ?? '';
          return <String, dynamic>{
            'name': command,
            'description': '调用 ${descriptor['tool'] ?? command}',
            'inputSchema':
                descriptor['inputSchema'] ?? const <String, dynamic>{},
            'annotations': descriptor['annotations'] is Map
                ? Map<String, dynamic>.from(descriptor['annotations'] as Map)
                : const <String, dynamic>{},
          };
        })
        .where((tool) => tool['name']?.toString().isNotEmpty == true)
        .toList(growable: false);
    widget.onMiniAppEvent?.call({
      'type': 'mcp.toolsChanged',
      'botId': widget.bot.stableBotId,
      'commands': _commands,
    });
  }

  Future<Map<String, dynamic>> _runCommand(MiniAppHostCommand command) async {
    await _ready.future.timeout(const Duration(seconds: 20));
    if (command.command.isEmpty) {
      return _runScopedCodexTurn(command.text);
    }
    final tool = _tools.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['name'] == command.command,
      orElse: () => null,
    );
    if (tool == null) {
      throw MiniAppHostException(
        'unknown_tool',
        '当前 MCP Server 没有 /${command.command} Tool',
      );
    }
    var arguments = _argumentsFor(tool, command.args);
    if (arguments == null) {
      if (!mounted) {
        throw const MiniAppHostException('host_not_ready', 'MCP App Host 已卸载');
      }
      final schema = tool['inputSchema'] is Map
          ? Map<String, dynamic>.from(tool['inputSchema'] as Map)
          : const <String, dynamic>{};
      arguments = await showMcpSchemaFormDialog(
        context,
        toolName: command.command,
        schema: schema,
      );
      if (arguments == null) {
        return {'cancelled': true, 'tool': command.command};
      }
    }
    if (_usesEmbeddedPluginRuntime &&
        tool['annotations'] is Map &&
        (tool['annotations'] as Map)['readOnlyHint'] != true) {
      final approved = await _approveRuntimeRequest({
        'title': '允许 /${command.command}？',
        'details': {
          'pluginId': _pluginId,
          'tool': command.command,
          'arguments': arguments,
          'annotations': tool['annotations'],
        },
      });
      if (!approved) {
        return {'cancelled': true, 'tool': command.command};
      }
      await MahayanaSdk.instance.execute({
        '@type': 'mahayana.plugin.approveLocal',
        'pluginId': _pluginId,
        'tool': command.command,
      });
    }
    final result = await _callTool(command.command, arguments);
    await _handleHostRequest(command.command, result);
    final text = _resultText(result);
    widget.onMiniAppEvent?.call({
      'type': 'mcp.toolResult',
      'botId': widget.bot.stableBotId,
      'tool': command.command,
      'text': text,
      'isError': result['isError'] == true,
      'result': result,
    });
    await _webView?.evaluateJavascript(
      source:
          'window.postMessage(${jsonEncode({
            'jsonrpc': '2.0',
            'method': 'ui/notifications/tool-result',
            'params': {'name': command.command, 'arguments': arguments, 'result': result},
          })}, "*");',
    );
    return result;
  }

  Future<Map<String, dynamic>> _runScopedCodexTurn(String message) async {
    final payload = await MahayanaSdk.instance.miniAppChat(
      pluginId: _pluginId,
      message: message,
      onApproval: _approveRuntimeRequest,
      onProgress: (progress) => unawaited(_emitProgress('agent', progress)),
    );
    _conversationId = payload['conversationId']?.toString();
    final text = payload['message']?.toString() ?? '';
    final completed = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : const <String, dynamic>{};
    final metadata = completed['metadata'] is Map
        ? Map<String, dynamic>.from(completed['metadata'] as Map)
        : const <String, dynamic>{};
    final result = <String, dynamic>{
      'content': [
        {'type': 'text', 'text': text},
      ],
      'structuredContent': {
        'pluginId': _pluginId,
        'conversationId': _conversationId,
        'provider': payload['provider'],
        'model': payload['model'],
        if (metadata.isNotEmpty) 'messageMetadata': metadata,
      },
    };
    widget.onMiniAppEvent?.call({
      'type': 'mcp.agentResult',
      'botId': widget.bot.stableBotId,
      'text': text,
      'result': result,
      if (metadata.isNotEmpty) 'metadata': metadata,
    });
    return result;
  }

  Map<String, dynamic>? _argumentsFor(
    Map<String, dynamic> tool,
    String remainder,
  ) {
    final schema = tool['inputSchema'] is Map
        ? Map<String, dynamic>.from(tool['inputSchema'] as Map)
        : const <String, dynamic>{};
    final properties = schema['properties'] is Map
        ? Map<String, dynamic>.from(schema['properties'] as Map)
        : const <String, dynamic>{};
    if (properties.isEmpty) return {};
    if (remainder.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(remainder);
        if (parsed is Map) {
          final arguments = Map<String, dynamic>.from(parsed);
          final required =
              (schema['required'] as List?)
                  ?.map((value) => value.toString())
                  .toList(growable: false) ??
              const <String>[];
          if (required.every(
            (field) => arguments.containsKey(field) && arguments[field] != '',
          )) {
            return arguments;
          }
          return null;
        }
      } catch (_) {
        // A plain remainder is a convenient shorthand for one string field.
      }
    }
    if (properties.length == 1) {
      final field = properties.entries.first;
      final fieldSchema = field.value is Map
          ? Map<String, dynamic>.from(field.value as Map)
          : const <String, dynamic>{};
      if (fieldSchema['type'] == 'string') return {field.key: remainder};
    }
    if (remainder.trim().isEmpty) return null;
    return null;
  }

  Future<Map<String, dynamic>> _callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    if (_usesEmbeddedPluginRuntime) {
      final payload = await MahayanaSdk.instance.execute({
        '@type': 'mahayana.plugin.callLocal',
        'pluginId': _pluginId,
        'tool': name,
        'arguments': arguments,
      });
      final result = payload['result'];
      if (result is Map) {
        final progress = payload['progress'];
        if (progress is List) {
          for (final update in progress.whereType<Map>()) {
            await _emitProgress(name, Map<String, dynamic>.from(update));
          }
        }
        return Map<String, dynamic>.from(result);
      }
      throw const MiniAppHostException(
        'invalid_local_plugin_result',
        '本地 CLI/WASM 没有返回 MCP Tool Result',
      );
    }
    final payload = await MahayanaSdk.instance.miniAppChat(
      pluginId: _pluginId,
      message: '/$name ${jsonEncode(arguments)}',
      onApproval: _approveRuntimeRequest,
      onProgress: (progress) => unawaited(_emitProgress(name, progress)),
    );
    final message = payload['message']?.toString() ?? '';
    final data = payload['data'];
    return {
      'content': [
        {'type': 'text', 'text': message},
      ],
      if (data is Map) 'structuredContent': Map<String, dynamic>.from(data),
    };
  }

  Future<void> _handleHostRequest(
    String tool,
    Map<String, dynamic> result,
  ) async {
    final structured = result['structuredContent'];
    if (structured is! Map) return;
    final structuredContent = Map<String, dynamic>.from(structured);
    final rawRequest = structuredContent['hostRequest'];
    if (rawRequest is! Map) return;
    final request = Map<String, dynamic>.from(rawRequest);
    final approved = await _approveRuntimeRequest({
      'title': '允许宿主执行 ${request['capability'] ?? '系统能力'}？',
      'details': {'pluginId': _pluginId, 'tool': tool, 'hostRequest': request},
    });
    if (!approved) {
      structuredContent['hostResult'] = {
        'handled': true,
        'ok': false,
        'cancelled': true,
      };
      result['structuredContent'] = structuredContent;
      return;
    }
    final taskId =
        (request['params'] is Map
            ? (request['params'] as Map)['taskId']?.toString()
            : null) ??
        'mcp_${DateTime.now().microsecondsSinceEpoch}';
    widget.onCliStart?.call(
      '${widget.bot.title} · ${request['capability']}',
      taskId,
    );
    final hostResult = await _capabilityBridge.execute(
      request,
      onProgress: (update) {
        final message = update['message']?.toString() ?? '';
        if (message.isNotEmpty) widget.onCliLog?.call(taskId, message);
        unawaited(_emitProgress(tool, update));
      },
    );
    structuredContent['hostResult'] = hostResult;
    result['structuredContent'] = structuredContent;
    widget.onMiniAppEvent?.call({
      'type': 'mcp.hostResult',
      'botId': widget.bot.stableBotId,
      'tool': tool,
      'request': request,
      'result': hostResult,
    });
  }

  Future<void> _emitProgress(String tool, Map<String, dynamic> update) async {
    final event = {
      'type': 'mcp.progress',
      'botId': widget.bot.stableBotId,
      'pluginId': _pluginId,
      'tool': tool,
      ...update,
    };
    widget.onMiniAppEvent?.call(event);
    await _webView?.evaluateJavascript(
      source:
          'window.postMessage(${jsonEncode({
            'jsonrpc': '2.0',
            'method': 'notifications/progress',
            'params': {'tool': tool, ...update},
          })}, "*");',
    );
  }

  Future<bool> _approveRuntimeRequest(Map<String, dynamic> request) async {
    if (!mounted) return false;
    final details = request['details'] is Map
        ? Map<String, dynamic>.from(request['details'] as Map)
        : const <String, dynamic>{};
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request['title']?.toString() ?? '允许 MCP Tool 调用？'),
            content: SingleChildScrollView(
              child: Text(const JsonEncoder.withIndent('  ').convert(details)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('允许本次会话'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _localRustHostHtml() {
    final title = const HtmlEscape().convert(widget.bot.title);
    final pluginId = const HtmlEscape().convert(_pluginId);
    return '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font-family:system-ui;margin:0;padding:24px;background:#f7f8fa;color:#17202a}.card{max-width:680px;margin:auto;padding:24px;border-radius:18px;background:white;box-shadow:0 8px 30px #0001}code{color:#356ae6}</style></head><body><div class="card"><h2>$title</h2><p>插件由大乘 Rust/Codex MCP Runtime 托管。</p><p><code>$pluginId</code></p><p>请在宿主输入框键入 <code>/</code> 查看可用命令。</p></div></body></html>''';
  }

  String _pluginFolderHtml(CodexPluginDescriptor? plugin) {
    if (plugin == null) return _localRustHostHtml();
    const escape = HtmlEscape();
    final title = escape.convert(plugin.title);
    final pluginId = escape.convert(plugin.id);
    final rootPath = escape.convert(plugin.rootPath);
    final skillChips = plugin.skills
        .map(
          (skill) => '<span class="chip skill">${escape.convert(skill)}</span>',
        )
        .join();
    final mcpChips = plugin.mcpServers
        .map(
          (server) => '<span class="chip mcp">${escape.convert(server)}</span>',
        )
        .join();
    final fileRows = plugin.files.map((entry) {
      final depth = p.split(entry.path).length - 1;
      final name = escape.convert(p.basename(entry.path));
      final relativePath = escape.convert(entry.path);
      final icon = entry.isDirectory ? '📁' : '📄';
      final size = entry.isDirectory ? '' : _formatFileSize(entry.size);
      return '''<div class="file-row" style="--depth:$depth" title="$relativePath"><span class="file-icon">$icon</span><span class="file-name">$name</span><span class="file-path">$relativePath</span><span class="file-size">$size</span></div>''';
    }).join();
    final emptyFiles = plugin.files.isEmpty
        ? '<div class="empty">没有可显示的文件，或插件目录当前不可读。</div>'
        : '';
    final skillSection = skillChips.isEmpty
        ? '<span class="empty-inline">未声明 Skills</span>'
        : skillChips;
    final mcpSection = mcpChips.isEmpty
        ? '<span class="empty-inline">未声明 MCP Server</span>'
        : mcpChips;
    return '''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    :root{color-scheme:dark;font-family:Inter,ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#111315;color:#f5f5f7}
    *{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 14% -10%,#34303a 0,transparent 34%),#111315;min-height:100vh}
    main{max-width:980px;margin:auto;padding:30px 28px 52px}.eyebrow{color:#e56a54;font-size:12px;font-weight:800;letter-spacing:.12em;text-transform:uppercase}
    h1{margin:8px 0 5px;font-size:29px;letter-spacing:-.03em}.plugin-id{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#a9abb2}
    .notice{margin:22px 0;padding:15px 17px;border:1px solid #4a4141;background:#251f20;border-radius:13px;color:#e9d7d3;line-height:1.55}
    .path{margin:14px 0 20px;padding:11px 13px;background:#191b1e;border:1px solid #2c2f34;border-radius:9px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#b7bac2;overflow-wrap:anywhere}
    .meta-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:22px}.meta-card{background:#191b1e;border:1px solid #2b2e33;border-radius:13px;padding:14px}
    .meta-title{font-size:12px;font-weight:800;color:#999da7;margin-bottom:9px}.chip{display:inline-block;margin:0 6px 6px 0;padding:5px 8px;border-radius:7px;font:11px ui-monospace,SFMono-Regular,Menlo,monospace}
    .skill{background:#35283b;color:#e5c9f0}.mcp{background:#20353a;color:#bce6ea}.empty-inline{font-size:12px;color:#777c86}
    .folder{overflow:hidden;background:#17191c;border:1px solid #2b2e33;border-radius:14px}.folder-head{display:flex;justify-content:space-between;padding:13px 15px;border-bottom:1px solid #2b2e33;font-size:12px;color:#a7aab2}
    .file-row{display:grid;grid-template-columns:22px minmax(130px,260px) minmax(180px,1fr) 70px;align-items:center;gap:8px;min-height:35px;padding:5px 13px 5px calc(13px + var(--depth) * 16px);border-bottom:1px solid #22252a;font-size:12px}
    .file-row:last-child{border-bottom:0}.file-row:hover{background:#202328}.file-icon{font-size:14px}.file-name{font-weight:650;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file-path{color:#777c86;font:10px ui-monospace,SFMono-Regular,Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file-size{text-align:right;color:#666b75;font:10px ui-monospace,SFMono-Regular,Menlo,monospace}.empty{padding:30px;text-align:center;color:#777c86}
    @media(max-width:680px){main{padding:22px 15px 40px}.meta-grid{grid-template-columns:1fr}.file-row{grid-template-columns:22px 1fr 62px}.file-path{display:none}}
  </style>
</head>
<body><main>
  <div class="eyebrow">Codex Plugin Package</div>
  <h1>$title</h1>
  <div class="plugin-id">$pluginId</div>
  <div class="notice">这个插件没有提供应用 UI，因此这里直接显示它的插件文件夹内容。插件机器人仍可在 Codex 输入框通过 <strong>@</strong> 调用。</div>
  <div class="path">$rootPath</div>
  <div class="meta-grid">
    <section class="meta-card"><div class="meta-title">SKILLS</div>$skillSection</section>
    <section class="meta-card"><div class="meta-title">MCP SERVERS</div>$mcpSection</section>
  </div>
  <section class="folder">
    <div class="folder-head"><span>插件文件</span><span>${plugin.files.length} 项</span></div>
    $fileRows$emptyFiles
  </section>
</main></body></html>''';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  WebUri? get _pluginUiBaseUrl {
    final plugin = _pluginPackage;
    final entry = plugin?.uiEntryPath;
    if (plugin == null || entry == null || entry.isEmpty) return null;
    final directory = p.dirname(p.join(plugin.rootPath, entry));
    final uri = Uri.file(
      '$directory${p.separator}',
      windows: defaultTargetPlatform == TargetPlatform.windows,
    );
    return WebUri(uri.toString());
  }

  String _resultText(Map<String, dynamic> result) {
    final content = result['content'];
    if (content is List) {
      final text = content
          .whereType<Map>()
          .where((item) => item['type'] == 'text')
          .map((item) => item['text']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .join('\n');
      if (text.isNotEmpty) return text;
    }
    return const JsonEncoder.withIndent(
      ' ',
    ).convert(result['structuredContent'] ?? result);
  }

  String _message(Object error) =>
      error is MiniAppHostException ? error.message : error.toString();

  @override
  Widget build(BuildContext context) {
    if (widget.headless) return const SizedBox.shrink();
    final body = _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          )
        : _uiHtml == null
        ? const Center(child: CircularProgressIndicator())
        : InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _uiHtml!,
              mimeType: 'text/html',
              encoding: 'utf-8',
              baseUrl: _pluginUiBaseUrl,
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: false,
            ),
            onWebViewCreated: (controller) {
              _webView = controller;
              controller.addJavaScriptHandler(
                handlerName: 'McpAppsBridge',
                callback: (arguments) async {
                  if (arguments.isEmpty || arguments.first is! Map) {
                    throw const MiniAppHostException(
                      'invalid_request',
                      'MCP Apps bridge 请求无效',
                    );
                  }
                  final request = Map<String, dynamic>.from(
                    arguments.first as Map,
                  );
                  final params = request['params'] is Map
                      ? Map<String, dynamic>.from(request['params'] as Map)
                      : const <String, dynamic>{};
                  final name = params['name']?.toString() ?? '';
                  final tool = _tools.cast<Map<String, dynamic>?>().firstWhere(
                    (item) => item?['name'] == name,
                    orElse: () => null,
                  );
                  if (tool == null) {
                    throw MiniAppHostException(
                      'unknown_tool',
                      '当前 MCP Server 没有 $name Tool',
                    );
                  }
                  final args = params['arguments'] is Map
                      ? Map<String, dynamic>.from(params['arguments'] as Map)
                      : <String, dynamic>{};
                  return _runCommand(
                    MiniAppHostCommand(
                      text: '/$name ${jsonEncode(args)}',
                      command: name,
                      args: jsonEncode(args),
                      background: false,
                    ),
                  );
                },
              );
            },
            onLoadStop: (controller, _) async {
              await controller.evaluateJavascript(
                source: '''
if (!window.__mahayanaMcpAppsBridgeInstalled) {
  window.__mahayanaMcpAppsBridgeInstalled = true;
  window.addEventListener('message', async (event) => {
    const request = event.data;
    if (!request || request.jsonrpc !== '2.0' || request.method !== 'tools/call') return;
    try {
      const result = await window.flutter_inappwebview.callHandler('McpAppsBridge', request);
      window.postMessage({ jsonrpc: '2.0', id: request.id, result }, '*');
    } catch (error) {
      window.postMessage({
        jsonrpc: '2.0',
        id: request.id,
        error: { code: -32000, message: String(error) },
      }, '*');
    }
  });
}
''',
              );
            },
          );
    if (!widget.inline) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.bot.title)),
        body: body,
      );
    }
    return Column(
      children: [
        Material(
          color: const Color(0xFF17212B),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onMinimize,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                Expanded(
                  child: Text(
                    widget.bot.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class MiniAppHostException implements Exception {
  const MiniAppHostException(this.code, this.message, {this.data});

  final String code;
  final String message;
  final Object? data;

  @override
  String toString() => message;
}
