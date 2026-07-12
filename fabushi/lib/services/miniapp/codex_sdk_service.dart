import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../services/app_settings.dart';

/// Codex 大模型引擎提供商枚举
enum CodexModelProvider {
  openAI,
  deepSeek,
  anthropicClaude,
  googleGemini,
  localOllama,
}

/// Codex 客户端运行时大模型配置
class CodexModelConfigDart {
  final CodexModelProvider provider;
  final String baseUrl;
  final String apiKey;
  final String modelName;
  final double temperature;

  const CodexModelConfigDart({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.temperature = 0.1,
  });

  factory CodexModelConfigDart.deepSeek({required String apiKey}) {
    return CodexModelConfigDart(
      provider: CodexModelProvider.deepSeek,
      baseUrl: AppConfig.openClawDeepSeekProxyBaseUrl,
      apiKey: apiKey.isEmpty ? 'dacheng-openclaw-proxy' : apiKey,
      modelName: 'deepseek-chat',
    );
  }

  factory CodexModelConfigDart.ollama({String modelName = 'deepseek-r1:8b'}) {
    return CodexModelConfigDart(
      provider: CodexModelProvider.localOllama,
      baseUrl: 'http://localhost:11434/v1',
      apiKey: 'ollama',
      modelName: modelName,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'modelName': modelName,
        'temperature': temperature,
      };
}

/// Codex 结构化流式事件类型
enum CodexEventType {
  reasoningProgress,
  toolCallTriggered,
  sandboxFileModified,
  turnCompleted,
  error,
}

/// Codex 结构化事件数据
class CodexEventDart {
  final CodexEventType type;
  final String? content;
  final String? toolName;
  final Map<String, dynamic>? arguments;
  final String? filePath;
  final String? newContent;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const CodexEventDart({
    required this.type,
    this.content,
    this.toolName,
    this.arguments,
    this.filePath,
    this.newContent,
    this.errorMessage,
    this.metadata,
  });

  factory CodexEventDart.reasoning(String content) =>
      CodexEventDart(type: CodexEventType.reasoningProgress, content: content);

  factory CodexEventDart.toolCall(String name, Map<String, dynamic> args) =>
      CodexEventDart(type: CodexEventType.toolCallTriggered, toolName: name, arguments: args);

  factory CodexEventDart.fileModified(String path, String content) =>
      CodexEventDart(type: CodexEventType.sandboxFileModified, filePath: path, newContent: content);

  factory CodexEventDart.completed(
    String summary, {
    Map<String, dynamic>? metadata,
  }) => CodexEventDart(
    type: CodexEventType.turnCompleted,
    content: summary,
    metadata: metadata,
  );

  factory CodexEventDart.error(String err) =>
      CodexEventDart(type: CodexEventType.error, errorMessage: err);
}

/// 全平台通用的 Codex Sdk 客户端抽象：对接底层 FFI / 内存沙盒 / 小程序预览热重载
class CodexSdk extends ChangeNotifier {
  static final CodexSdk instance = CodexSdk._();
  CodexSdk._();

  static const Duration _generationTimeout = Duration(seconds: 120);

  CodexModelConfigDart _config =
      CodexModelConfigDart.deepSeek(apiKey: 'dacheng-openclaw-proxy');
  final Map<String, String> _virtualVfs = {};
  final StreamController<CodexEventDart> _eventController = StreamController<CodexEventDart>.broadcast();

  Stream<CodexEventDart> get events => _eventController.stream;
  Map<String, String> get virtualVfs => Map.unmodifiable(_virtualVfs);
  CodexModelConfigDart get config => _config;

  void configure(CodexModelConfigDart config) {
    _config = config;
    notifyListeners();
  }

  String _deepSeekProxyBaseUrl() {
    return AppConfig.openClawDeepSeekProxyBaseUrl;
  }

  String _backendDeepSeekModelId() {
    final raw = _config.modelName.trim();
    final modelId = raw.contains('/') ? raw.split('/').last.trim() : raw;
    if (modelId == 'deepseek-chat' || modelId == 'deepseek-reasoner') {
      return modelId;
    }
    return 'deepseek-chat';
  }

  Map<String, String> _firstPartyHeaders({
    String accept = 'application/json',
    String? authToken,
  }) {
    final token = authToken?.trim() ?? '';
    return {
      'Accept': accept,
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(value);
  }

  String _responseFailureMessage(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) return 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
        final error = decoded['error'];
        if (error is Map) {
          final nested = error['message']?.toString().trim() ?? '';
          if (nested.isNotEmpty) return nested;
        }
        if (error != null && error.toString().trim().isNotEmpty) {
          return error.toString().trim();
        }
      }
    } catch (_) {
      // Preserve the upstream body below when it is not JSON.
    }
    return body;
  }

  Stream<CodexEventDart> _sendBackendBotFather({
    required String prompt,
    String? authToken,
    String? username,
  }) async* {
    final backendUri = AppConfig.buildBackendUri(
      '/api/botfather/generate-miniapp',
    );
    final response = await http
        .post(
          backendUri,
          headers: _firstPartyHeaders(authToken: authToken),
          body: jsonEncode({
            'prompt': prompt,
            if (username != null && username.trim().isNotEmpty)
              'username': username.trim(),
          }),
        )
        .timeout(_generationTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_responseFailureMessage(response));
    }

    final decodedValue = jsonDecode(utf8.decode(response.bodyBytes));
    final decoded = _jsonMap(decodedValue);
    if (decoded['success'] != true) {
      throw StateError(
        decoded['message']?.toString().trim().isNotEmpty == true
            ? decoded['message'].toString().trim()
            : '机器人之父后端没有返回成功状态',
      );
    }

    final miniApp = _jsonMap(decoded['miniApp']);
    final bot = _jsonMap(decoded['bot']);
    final generation = _jsonMap(decoded['generation']);
    var html = miniApp['sourceHtml']?.toString() ?? '';

    // Compatibility with an older backend contract that only returned an
    // entry URL. The generated source remains first-party and scan-checked.
    if (html.trim().isEmpty) {
      final entryUrl = miniApp['entryUrl']?.toString().trim() ?? '';
      final entryUri = Uri.tryParse(entryUrl);
      if (entryUri != null &&
          (entryUri.scheme == 'https' || entryUri.scheme == 'http')) {
        final sourceResponse = await http
            .get(
              entryUri,
              headers: _firstPartyHeaders(
                accept: 'text/html',
                authToken: authToken,
              )..remove('Content-Type'),
            )
            .timeout(_generationTimeout);
        if (sourceResponse.statusCode >= 200 &&
            sourceResponse.statusCode < 300) {
          html = utf8.decode(sourceResponse.bodyBytes);
        }
      }
    }

    if (html.trim().isEmpty || !html.toLowerCase().contains('<html')) {
      throw StateError('机器人之父后端没有返回可预览的小程序 HTML');
    }

    yield CodexEventDart.toolCall(
      'create_file',
      {'path': 'index.html', 'content': html},
    );
    updateSandboxFile('index.html', html);
    yield CodexEventDart.fileModified('index.html', html);

    final provider = generation['provider']?.toString().trim() ?? '';
    final model = generation['model']?.toString().trim() ?? '';
    final generatorLabel = provider == 'template'
        ? '安全模板'
        : model.isNotEmpty
        ? '$provider / $model'
        : provider.isNotEmpty
        ? provider
        : 'Codex';
    yield CodexEventDart.completed(
      '小程序云端构建完成（$generatorLabel），已保存到个人沙箱。',
      metadata: {
        'provider': provider.isEmpty ? 'codex' : provider,
        'persisted': true,
        'miniApp': miniApp,
        'bot': bot,
        'generation': generation,
      },
    );
  }

  Stream<CodexEventDart> _sendBackendDeepSeekProxyStream({
    required String prompt,
    String? authToken,
    String? username,
  }) async* {
    final uri = Uri.parse('${_deepSeekProxyBaseUrl()}/chat/completions');
    final model = _backendDeepSeekModelId();
    final body = jsonEncode({
      'model': model,
      'temperature': _config.temperature,
      'messages': [
        {
          'role': 'system',
          'content':
              '你是 Fabushi 机器人之父。请直接输出经过优化的 HTML 单文件小程序源码，包在 ```html 和 ``` 中。不要多余解释。'
        },
        {'role': 'user', 'content': prompt}
      ],
      'stream': true,
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
    });

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (authToken != null && authToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${authToken.trim()}',
      })
      ..body = body;

    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyText = await utf8.decodeStream(response.stream);
        throw StateError(
          bodyText.trim().isEmpty ? 'Codex DeepSeek 代理请求失败' : bodyText,
        );
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final buffer = StringBuffer();
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        if (payload == '[DONE]') break;

        try {
          final val = jsonDecode(payload);
          if (val is Map && val['error'] != null) {
            throw StateError(val['error'].toString());
          }
          final choices = val is Map ? val['choices'] as List? : null;
          if (choices == null || choices.isEmpty) continue;
          final delta = choices[0]['delta'] as Map?;
          if (delta == null) continue;

          final reasoning = delta['reasoning_content'] as String?;
          if (reasoning != null && reasoning.isNotEmpty) {
            yield CodexEventDart.reasoning(reasoning);
          }
          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            buffer.write(content);
          }
        } catch (error) {
          if (error is StateError) rethrow;
        }
      }

      final fullText = buffer.toString();
      final htmlMatch = RegExp(r'```html\s*([\s\S]*?)\s*```')
          .firstMatch(fullText);
      final html = htmlMatch != null ? htmlMatch.group(1)! : fullText;
      if (!html.trim().startsWith('<')) {
        throw StateError('DeepSeek 兼容代理没有返回有效 HTML');
      }
      yield CodexEventDart.toolCall(
        'create_file',
        {'path': 'index.html', 'content': html},
      );
      updateSandboxFile('index.html', html);
      yield CodexEventDart.fileModified('index.html', html);
      yield CodexEventDart.completed(
        'Codex 兼容代理 ($model) 生成完毕。',
        metadata: {
          'provider': 'legacy-deepseek-proxy',
          'persisted': false,
        },
      );
    } finally {
      client.close();
    }
  }

  /// 从 AppSettings 初始化并载入用户的自定义 API 配置
  Future<void> initFromSettings() async {
    final key = await AppSettings.getCodexApiKey();
    final url = await AppSettings.getCodexBaseUrl();
    final model = await AppSettings.getCodexModelName();

    _config = CodexModelConfigDart(
      provider: CodexModelProvider.deepSeek,
      baseUrl: url,
      apiKey: key,
      modelName: model,
    );
    notifyListeners();
  }

  /// 在内存沙盒中创建或覆盖文件，并触发热重载监听
  void updateSandboxFile(String path, String content) {
    _virtualVfs[path] = content;
    _eventController.add(CodexEventDart.fileModified(path, content));
    notifyListeners();
  }

  /// 对沙盒代码文件执行自我修复与热补丁替换
  bool patchSandboxCode(String path, String findStr, String replaceStr) {
    if (!_virtualVfs.containsKey(path)) return false;
    final current = _virtualVfs[path]!;
    if (!current.contains(findStr)) return false;
    final updated = current.replaceAll(findStr, replaceStr);
    updateSandboxFile(path, updated);
    return true;
  }

  /// 发起对 Codex 底层或第三方 API/服务端的会话请求
  Stream<CodexEventDart> sendMessage({
    required String prompt,
    required String workspaceId,
    bool isSelfHealing = false,
    String? authToken,
    String? username,
  }) async* {
    // Never let a previous turn's file mask a failed generation in this turn.
    _virtualVfs.remove('index.html');

    if (isSelfHealing) {
      yield CodexEventDart.reasoning('捕捉到沙盒运行异常，正在启动 Codex 自我修复程序...');
    } else {
      yield CodexEventDart.reasoning(
        '分析用户小程序构建需求，使用大乘 DeepSeek 后端: ${_backendDeepSeekModelId()}...',
      );
    }

    try {
      // 1. The first-party Bot Father endpoint owns official Codex SDK
      // orchestration, account quota, security scanning, and persistence.
      yield* _sendBackendBotFather(
        prompt: prompt,
        authToken: authToken,
        username: username,
      );
      return;
    } catch (e) {
      yield CodexEventDart.error('机器人之父 Codex 后端异常: $e');
    }

    try {
      // 2. Compatibility fallback for a partially upgraded backend.
      yield* _sendBackendDeepSeekProxyStream(
        prompt: prompt,
        authToken: authToken,
        username: username,
      );
      return;
    } catch (e) {
      yield CodexEventDart.error('Codex 兼容代理异常: $e');
    }

    // 3. Keep the composer usable offline, while clearly identifying that
    // this is not a successful Codex generation.
    const fallbackHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>机器人之父-沙箱小程序</title>
  <style>
    body { font-family: -apple-system, system-ui; background: #121212; color: #fff; padding: 16px; }
    .card { background: #1e1e1e; border-radius: 12px; padding: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.5); }
    button { background: #3d8bff; color: white; border: none; padding: 10px 16px; border-radius: 8px; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2 id="title">沙箱小程序应用</h2>
    <p id="desc">由 Codex SDK 驱动构建</p>
    <button onclick="alert('执行成功')">体验功能</button>
  </div>
</body>
</html>
''';
    yield CodexEventDart.toolCall('create_file', {'path': 'index.html', 'content': fallbackHtml});
    updateSandboxFile('index.html', fallbackHtml);
    yield CodexEventDart.fileModified('index.html', fallbackHtml);
    yield CodexEventDart.completed(
      '云端 Codex 暂不可用，已加载本地离线模板；恢复连接后可继续生成完整应用。',
      metadata: {
        'provider': 'offline-template',
        'persisted': false,
      },
    );
  }
}
