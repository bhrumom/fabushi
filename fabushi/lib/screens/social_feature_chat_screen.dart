import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_model.dart';
import '../features/flashcards/application/content_pipeline.dart';
import '../features/flashcards/application/flashcard_service.dart';
import '../features/flashcards/data/flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_models.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../models/mini_app_model.dart';
import '../services/dacheng_ai_service.dart';
import '../services/dharma_publish_service.dart';
import 'mini_app_host_screen.dart';
import '../widgets/social/social_feature_bot.dart';

class SocialFeatureChatScreen extends StatefulWidget {
  const SocialFeatureChatScreen({super.key, required this.bot});

  final SocialFeatureBot bot;

  @override
  State<SocialFeatureChatScreen> createState() =>
      _SocialFeatureChatScreenState();
}

class _SocialFeatureChatScreenState extends State<SocialFeatureChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, List<_ChatMessage>> _messages = {};
  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  final DharmaPublishService _publishService = DharmaPublishService();
  final http.Client _httpClient = http.Client();
  final Set<DharmaPublishPlatform> _platforms = {
    DharmaPublishPlatform.xiaohongshu,
  };
  FlashcardCreationMode _flashcardMode = FlashcardCreationMode.randomCloze;
  bool _busy = false;
  String _activity = '';
  bool _miniAppPanelOpen = false;
  SocialFeatureBot? _panelBot;
  final StreamController<String> _miniAppMessageController = StreamController<String>.broadcast();

  SocialFeatureBot get _bot => widget.bot;
  SocialFeatureBot get _activePanelBot => _panelBot ?? _bot;
  MiniAppBotKind get _kind => widget.bot.effectiveKind;
  List<_ChatMessage> get _botMessages =>
      _messages.putIfAbsent(widget.bot.stableBotId, () => []);

  @override
  void initState() {
    super.initState();
    _flashcardRepository = FlashcardRepository();
    _contentPipeline = ContentPipeline(repository: _flashcardRepository);
    _flashcardService = FlashcardService(
      repository: _flashcardRepository,
      aiService: DachengAiService(),
    );
    _ensureGreeting(widget.bot);
  }

  @override
  void didUpdateWidget(covariant SocialFeatureChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bot.stableBotId != widget.bot.stableBotId) {
      _composer.clear();
      _miniAppPanelOpen = false;
      _panelBot = null;
      _ensureGreeting(widget.bot);
      _scrollBottom();
    }
  }

  @override
  void dispose() {
    _miniAppMessageController.close();
    _httpClient.close();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureGreeting(SocialFeatureBot bot) {
    final list = _messages.putIfAbsent(bot.stableBotId, () => []);
    if (list.isEmpty) list.add(_ChatMessage.bot(bot.greeting));
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final canSend = !_busy && _canSubmit(model);
    final chat = ColoredBox(
      color: const Color(0xFF0F1722),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(model),
            _buildModeBar(model),
            Expanded(child: _buildMessages(model)),
            _buildComposer(model, canSend),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final chatPaddingRight = (wide && _miniAppPanelOpen) ? 430.0 : 0.0;

        return Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(right: chatPaddingRight),
              child: chat,
            ),
            if (!wide && _miniAppPanelOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _miniAppPanelOpen = false),
                  child: Container(color: Colors.black54),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: wide ? 0 : (_miniAppPanelOpen ? constraints.maxHeight * 0.14 : constraints.maxHeight),
              bottom: wide ? 0 : (_miniAppPanelOpen ? 0 : -constraints.maxHeight * 0.86),
              right: wide ? (_miniAppPanelOpen ? 0 : -430) : 0,
              left: wide ? null : 0,
              width: wide ? 430 : null,
              child: Container(
                padding: wide ? const EdgeInsets.all(12) : const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B111A),
                  border: wide ? const Border(left: BorderSide(color: Color(0xFF223040))) : null,
                  borderRadius: wide ? null : const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: MiniAppHostScreen(
                  key: ValueKey(
                    '${_activePanelBot.stableBotId}:${_activePanelBot.stableMiniAppId}:${_activePanelBot.stableMiniAppEntryUrl}',
                  ),
                  bot: _activePanelBot,
                  inline: true,
                  messageStream: _miniAppMessageController.stream,
                  onCliStart: (title, taskId) {
                    if (!mounted) return;
                    setState(() {
                      _botMessages.add(_ChatMessage.cliTask(title, taskId));
                    });
                    _scrollBottom();
                  },
                  onCliLog: (taskId, log) {
                    if (!mounted) return;
                    setState(() {
                      final msg = _botMessages.lastWhere((m) => m.cliTaskId == taskId, orElse: () => _botMessages.first);
                      if (msg.cliLogs != null) {
                        msg.cliLogs!.add(log);
                      }
                    });
                    _scrollBottom();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(FileTransferModel model) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(bottom: BorderSide(color: Color(0xFF223040))),
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.only(right: 14),
              constraints: const BoxConstraints(),
            ),
          CircleAvatar(
            radius: 24,
            backgroundColor: _bot.avatarColor,
            child: Icon(_bot.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bot.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusText(model),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF91A3B7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '搜索',
            onPressed: () {},
            icon: const Icon(Icons.search, color: Color(0xFF91A3B7)),
          ),
          IconButton(
            tooltip: '拨打电话',
            onPressed: () {},
            icon: const Icon(Icons.call_outlined, color: Color(0xFF91A3B7)),
          ),
          IconButton(
            tooltip: _miniAppPanelOpen ? '关闭侧栏' : '打开侧栏',
            onPressed: _openMiniAppPanel,
            icon: Icon(
              _miniAppPanelOpen ? Icons.web_asset_off : Icons.web_asset,
              color: const Color(0xFF91A3B7),
            ),
          ),
          IconButton(
            tooltip: '更多选项',
            onPressed: () => _openCurrentSettings(model),
            icon: const Icon(Icons.more_vert, color: Color(0xFF91A3B7)),
          ),
        ],
      ),
    );
  }

  String _statusText(FileTransferModel model) {
    switch (_kind) {
      case MiniAppBotKind.globalDharma:
        if (model.isPreparingSend) return model.preparingSendMessage;
        return model.isTransferring
            ? '正在发送'
            : 'bot · ${model.isLooping ? "循环" : "单轮"} · ${model.isGlobalSendEnabled ? "全球" : "本地"}';
      case MiniAppBotKind.flashcards:
        return 'bot · 当前模式：${_flashcardMode.label}';
      case MiniAppBotKind.platformPublish:
        return 'bot · 平台：${_platformSummary()}';
      case MiniAppBotKind.botFather:
        return 'bot · 个人沙箱小程序生成器';
      case MiniAppBotKind.assistant:
      case MiniAppBotKind.thirdParty:
        return 'bot';
    }
  }

  Widget _buildModeBar(FileTransferModel model) {
    final chips = switch (_kind) {
      MiniAppBotKind.globalDharma => <Widget>[],
      MiniAppBotKind.flashcards => <Widget>[],
      MiniAppBotKind.platformPublish => <Widget>[],
      MiniAppBotKind.botFather => <Widget>[
        _ControlPill(
          icon: Icons.construction_outlined,
          label: '个人沙箱',
          active: true,
          onTap: _openMiniAppPanel,
        ),
        const _ControlPill(
          icon: Icons.fact_check_outlined,
          label: '审核后公开',
          active: false,
          onTap: null,
        ),
      ],
      MiniAppBotKind.assistant || MiniAppBotKind.thirdParty => <Widget>[
        _ControlPill(
          icon: _bot.icon,
          label: '小程序面板',
          active: _miniAppPanelOpen,
          onTap: _openMiniAppPanel,
        ),
      ],
    };

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF111B26),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2B38))),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _buildMessages(FileTransferModel model) {
    final showProgress =
        _kind == MiniAppBotKind.globalDharma &&
        (model.isPreparingSend || model.isTransferring);
    final count =
        _botMessages.length + (_busy ? 1 : 0) + (showProgress ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index < _botMessages.length) {
          return _MessageBubble(
            message: _botMessages[index],
            bot: _bot,
            onDeck: _openDeck,
            onOpenMiniApp: () => setState(() => _miniAppPanelOpen = true),
          );
        }
        if (_busy && index == _botMessages.length) {
          return _ThinkingBubble(label: _activity.isEmpty ? '正在处理' : _activity);
        }
        return _GlobalProgress(model: model);
      },
    );
  }

  Widget _buildComposer(FileTransferModel model, bool canSend) {
    final hasMiniApp = _bot.miniAppId != null && _bot.miniAppId!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(top: BorderSide(color: Color(0xFF223040))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasMiniApp)
            Padding(
              padding: const EdgeInsets.only(right: 4.0, bottom: 4),
              child: ElevatedButton.icon(
                onPressed: () => _openMiniAppPanel(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF40A7E3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.web_asset, size: 20),
                label: const Text(
                  '打开应用',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          IconButton(
            tooltip: '附件',
            onPressed: () {},
            icon: const Icon(
              Icons.attach_file,
              color: Color(0xFF91A3B7),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _composer,
              enabled: !_busy,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: _bot.inputHint,
                hintStyle: const TextStyle(color: Color(0xFF6E7F92)),
                filled: true,
                fillColor: const Color(0xFF17212B), // Match bg to hide border
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF91A3B7)),
                  onPressed: () {},
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canSend) _submit(model);
              },
            ),
          ),
          const SizedBox(width: 8),
          if (canSend)
            IconButton(
              tooltip: '发送',
              onPressed: () => _submit(model),
              icon: Icon(
                _busy ? Icons.more_horiz : Icons.send,
                color: const Color(0xFF40A7E3),
                size: 28,
              ),
            )
          else
            IconButton(
              tooltip: '语音留言',
              onPressed: () {},
              icon: const Icon(
                Icons.mic_none,
                color: Color(0xFF91A3B7),
                size: 28,
              ),
            ),
        ],
      ),
    );
  }

  bool _canSubmit(FileTransferModel model) {
    final text = _composer.text.trim();
    switch (_kind) {
      case MiniAppBotKind.globalDharma:
      case MiniAppBotKind.flashcards:
      case MiniAppBotKind.platformPublish:
        return text.isNotEmpty;
      case MiniAppBotKind.botFather:
      case MiniAppBotKind.assistant:
      case MiniAppBotKind.thirdParty:
        return text.isNotEmpty;
    }
  }

  void _submit(FileTransferModel model) {
    switch (_kind) {
      case MiniAppBotKind.globalDharma:
      case MiniAppBotKind.flashcards:
      case MiniAppBotKind.platformPublish:
        _startMiniAppChat();
        return;
      case MiniAppBotKind.botFather:
        unawaited(_startBotFather());
        return;
      case MiniAppBotKind.assistant:
      case MiniAppBotKind.thirdParty:
        unawaited(_startGenericBotChat());
        return;
    }
  }

  void _startMiniAppChat() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    setState(() {
      _botMessages.add(_ChatMessage.user(text));
      _botMessages.add(_ChatMessage.miniAppAction(
        '已收到消息，正在后台静默处理。您随时可以点击下方组件进入应用查看。',
        '打开 ${_bot.title}',
      ));
    });
    _scrollBottom();
    
    // Send to background silent webview
    _miniAppMessageController.add(text);
  }

  Future<void> _startBotFather() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final auth = Provider.of<AuthModel?>(context, listen: false);
    setState(() {
      _botMessages.add(_ChatMessage.user(text));
      _busy = true;
      _activity = '正在生成个人沙箱小程序...';
    });
    _scrollBottom();

    try {
      final token = auth?.authToken;
      final response = await _httpClient
          .post(
            AppConfig.buildBackendUri('/api/botfather/generate-miniapp'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'prompt': text,
              'username': auth?.currentUser?.username,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] == false) {
        throw StateError((data['message'] ?? '生成失败').toString());
      }
      final miniApp = Map<String, dynamic>.from(
        data['miniApp'] as Map? ?? const {},
      );
      final generatedBotJson = Map<String, dynamic>.from(
        data['bot'] as Map? ?? const {},
      );
      final generatedBot = generatedBotJson.isEmpty
          ? null
          : SocialFeatureBot.fromMiniApp(
              MiniAppBot.fromJson(generatedBotJson),
              index: 0,
              manifest: miniApp.isEmpty
                  ? null
                  : MiniAppManifest.fromJson(miniApp),
            );
      final title = miniApp['title']?.toString() ?? '个人沙箱小程序';
      final entryUrl = miniApp['entryUrl']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _botMessages.add(
          _ChatMessage.bot(
            [
              '已生成「$title」，并放入你的个人沙箱。',
              if (entryUrl.isNotEmpty) '入口：$entryUrl',
              '我已经为你打开小程序面板，也可以继续告诉我修改需求。',
            ].join('\n'),
          ),
        );
      });
      _openMiniAppPanel(generatedBot ?? _bot);
    } catch (e) {
      if (mounted) {
        _botMessages.add(_ChatMessage.error('生成失败：$e'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = '';
        });
      }
      _scrollBottom();
    }
  }

  Future<void> _startGenericBotChat() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final auth = Provider.of<AuthModel?>(context, listen: false);
    setState(() {
      _botMessages.add(_ChatMessage.user(text));
      _busy = true;
      _activity = '正在对话...';
    });
    _scrollBottom();
    try {
      final result = await DachengAiService().sendChat(
        message: text,
        token: auth?.authToken,
        username: auth?.currentUser?.username,
        isMember: auth?.hasPermission('premium') ?? false,
        client: {
          'surface': 'miniapp_bot_chat',
          'botId': _bot.stableBotId,
          'miniAppId': _bot.stableMiniAppId,
        },
      );
      if (!mounted) return;
      _botMessages.add(_ChatMessage.bot(result.message));
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('回复失败：$e'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = '';
        });
      }
      _scrollBottom();
    }
  }

  void _openMiniAppPanel([SocialFeatureBot? panelBot]) {
    setState(() {
      if (panelBot != null) _panelBot = panelBot;
      _miniAppPanelOpen = panelBot != null ? true : !_miniAppPanelOpen;
    });
  }

  Future<void> _startGlobal(FileTransferModel model) async {
    final text = _composer.text.trim();
    _composer.clear();
    setState(() {
      if (text.isNotEmpty) {
        _botMessages.add(_ChatMessage.user(text));
      }
      _busy = true;
      _activity = '正在准备素材...';
    });
    _scrollBottom();
    try {
      if (text.isNotEmpty) {
        await _saveTextToModel(
          model,
          text,
          '全球法布施',
          replaceExisting: !model.hasFiles,
        );
      }
      if (!model.hasFiles) throw StateError('请先输入文字、链接，或点击 + 添加素材。');
      setState(() => _activity = '正在启动发送...');
      await model.startGlobalTransfer();
      if (!mounted) return;
      _botMessages.add(
        _ChatMessage.bot(
          '已完成：${model.globalSentCount} 个节点，${model.globalDataSentMB.toStringAsFixed(2)} MB。',
        ),
      );
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('启动失败：$e'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = '';
        });
      }
      _scrollBottom();
    }
  }

  Future<void> _startFlashcards() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final progress = _ChatMessage.bot('正在准备内容...');
    setState(() {
      _botMessages.add(_ChatMessage.user(text));
      _botMessages.add(progress);
      _busy = true;
      _activity = '正在提取正文...';
    });
    _scrollBottom();
    try {
      final url = ContentPipeline.firstHttpUrl(text);
      final content = await _contentPipeline.prepare(
        ContentInput(
          text: text,
          url: url,
          title: url == null ? '背诵内容' : '链接内容',
        ),
      );
      if (content.isFailed) throw StateError(content.errorMessage ?? '内容提取失败');
      if (!mounted) return;
      final auth = Provider.of<AuthModel?>(context, listen: false);
      final input = FlashcardInput(
        title: content.title,
        text: content.text,
        documentId: content.document?.id,
        sourceUrl: content.sourceUrl,
      );
      final stream = _flashcardMode == FlashcardCreationMode.aiCards
          ? _flashcardService.generateAiCardsStream(
              input,
              token: auth?.authToken,
              username: auth?.currentUser?.username,
              isMember: auth?.hasPermission('premium') ?? false,
            )
          : _flashcardService.generateRandomClozeStream(input);
      await for (final event in stream) {
        if (!mounted) return;
        setState(() {
          _activity = event.message;
          progress.text = event.progress > 0
              ? '${event.message} (${event.progress}%)'
              : event.message;
        });
        if (event.isDone && event.deck != null) {
          _botMessages.add(
            _ChatMessage.deck(
              '制卡完成：${event.deck!.cardCount} 张 · ${event.deck!.mode.label}',
              event.deck!,
            ),
          );
        }
        if (event.isError) throw StateError(event.message);
        _scrollBottom();
      }
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('制卡失败：$e'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = '';
        });
      }
      _scrollBottom();
    }
  }

  Future<void> _startPublish(FileTransferModel model) async {
    final text = _composer.text.trim();
    _composer.clear();
    setState(() {
      if (text.isNotEmpty) {
        _botMessages.add(_ChatMessage.user(text));
      }
      _busy = true;
      _activity = '正在生成发布草稿...';
    });
    _scrollBottom();
    try {
      if (text.isNotEmpty) {
        await _saveTextToModel(model, text, '法布施发布', replaceExisting: true);
      }
      if (!model.hasFiles && text.isEmpty) {
        throw StateError('请输入正文/链接，或点击 + 添加素材。');
      }
      var draft = _publishService.buildDraftFromModel(
        model,
        fallbackText: text,
      );
      if (draft.title.trim().isEmpty) {
        draft = draft.copyWith(title: _publishService.suggestTitle(draft));
      }
      if (draft.body.trim().length < 12) {
        draft = draft.copyWith(body: _publishService.polishBody(draft));
      }
      _botMessages.add(
        _ChatMessage.bot(
          _publishService.buildPreviewMarkdown(draft, _platforms),
        ),
      );
      setState(() => _activity = '正在复制草稿并打开入口...');
      final results = await _publishService.publishDraft(
        draft: draft,
        platforms: _platforms,
      );
      if (!mounted) return;
      _botMessages.add(
        _ChatMessage.bot(
          results
              .map((r) => '${r.platform.info.shortLabel}：${r.message}')
              .join('\n'),
        ),
      );
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('发布失败：$e'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = '';
        });
      }
      _scrollBottom();
    }
  }

  Future<void> _saveTextToModel(
    FileTransferModel model,
    String text,
    String fallbackTitle, {
    required bool replaceExisting,
  }) async {
    final uri = Uri.tryParse(text);
    final isLink =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    await model.addTextContentForSending(
      title: isLink ? uri.host : _shortTitle(text, fallbackTitle),
      text: isLink ? '来源链接: ${uri.toString()}\n\n${uri.toString()}' : text,
      sourceKind: isLink ? '链接' : '文本',
      sourceUrl: isLink ? uri.toString() : null,
      previewText: text,
      replaceExisting: replaceExisting,
    );
  }

  String _shortTitle(String text, String fallback) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 18 ? normalized : normalized.substring(0, 18);
  }

  void _openCurrentSettings(FileTransferModel model) {
    switch (_kind) {
      case MiniAppBotKind.globalDharma:
        _showRegionSettings(model);
        return;
      case MiniAppBotKind.flashcards:
        _showFlashcardModeSelector();
        return;
      case MiniAppBotKind.platformPublish:
        _showPlatformSelector();
        return;
      case MiniAppBotKind.botFather:
      case MiniAppBotKind.assistant:
      case MiniAppBotKind.thirdParty:
        _openMiniAppPanel();
        return;
    }
  }

  void _showFlashcardModeSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomPanel(
        children: [
          _ModeTile(
            icon: Icons.auto_fix_high,
            title: '随机挖空',
            subtitle: '本地快速生成，无需 AI。',
            selected: _flashcardMode == FlashcardCreationMode.randomCloze,
            onTap: () {
              setState(
                () => _flashcardMode = FlashcardCreationMode.randomCloze,
              );
              Navigator.pop(ctx);
            },
          ),
          _ModeTile(
            icon: Icons.auto_awesome,
            title: 'AI 制卡',
            subtitle: '按要求生成问答/挖空卡。',
            selected: _flashcardMode == FlashcardCreationMode.aiCards,
            onTap: () {
              setState(() => _flashcardMode = FlashcardCreationMode.aiCards);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPlatformSelector() async {
    final selected = Set<DharmaPublishPlatform>.from(_platforms);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => _BottomPanel(
            maxHeightFactor: 0.74,
            children: [
              const Text(
                '选择发布平台',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  children: [
                    for (final platform in DharmaPublishService.allPlatforms)
                      CheckboxListTile(
                        value: selected.contains(platform),
                        onChanged: (v) => setSheetState(() {
                          if (v == true) {
                            selected.add(platform);
                          } else {
                            selected.remove(platform);
                          }
                        }),
                        title: Text(
                          platform.info.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          platform.info.description,
                          style: const TextStyle(color: Color(0xFF91A3B7)),
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _platforms
                            ..clear()
                            ..addAll(selected);
                        });
                        Navigator.pop(ctx);
                      },
                child: const Text('完成'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRegionSettings(FileTransferModel model) async {
    var global = model.isGlobalSendEnabled;
    var local = model.isLocalLoopbackEnabled;
    var field = model.isFieldEnergyMode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => _BottomPanel(
            children: [
              const Text(
                '全球法布施设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SwitchListTile(
                value: global,
                onChanged: (v) => setSheetState(() => global = v),
                title: const Text(
                  '全球节点',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SwitchListTile(
                value: field,
                onChanged: (v) => setSheetState(() => field = v),
                title: const Text(
                  '本地场能',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SwitchListTile(
                value: local,
                onChanged: (v) => setSheetState(() => local = v),
                title: const Text(
                  '本地转经轮',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  model.setGlobalSendEnabled(global);
                  model.setCountryList(global ? ['ALL'] : const []);
                  await model.setFieldEnergyMode(field);
                  model.setLocalLoopbackEnabled(local);
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('完成'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _platformSummary() {
    if (_platforms.isEmpty) return '未选择';
    final labels = _platforms.map((p) => p.info.shortLabel).toList();
    return labels.length <= 2
        ? labels.join('、')
        : '${labels.take(2).join('、')} 等 ${labels.length} 个';
  }

  void _openDeck(FlashcardDeck deck) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FlashcardStudyScreen(deck: deck, repository: _flashcardRepository),
      ),
    );
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ChatMessage {
  _ChatMessage(
    this.text, {
    required this.isUser,
    this.isError = false,
    this.deck,
    this.isMiniAppAction = false,
    this.actionLabel,
    this.cliTaskId,
    this.cliLogs,
  });
  String text;
  final bool isUser;
  final bool isError;
  final FlashcardDeck? deck;
  final bool isMiniAppAction;
  final String? actionLabel;
  final String? cliTaskId;
  List<String>? cliLogs;

  factory _ChatMessage.user(String text) => _ChatMessage(text, isUser: true);
  factory _ChatMessage.bot(String text) => _ChatMessage(text, isUser: false);
  factory _ChatMessage.error(String text) =>
      _ChatMessage(text, isUser: false, isError: true);
  factory _ChatMessage.deck(String text, FlashcardDeck deck) =>
      _ChatMessage(text, isUser: false, deck: deck);
  factory _ChatMessage.miniAppAction(String text, String actionLabel) =>
      _ChatMessage(text, isUser: false, isMiniAppAction: true, actionLabel: actionLabel);
  factory _ChatMessage.cliTask(String text, String taskId) =>
      _ChatMessage(text, isUser: false, cliTaskId: taskId, cliLogs: []);
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.bot,
    required this.onDeck,
    required this.onOpenMiniApp,
  });
  final _ChatMessage message;
  final SocialFeatureBot bot;
  final ValueChanged<FlashcardDeck> onDeck;
  final VoidCallback onOpenMiniApp;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: user
              ? const Color(0xFF2B5278)
              : message.isError
              ? const Color(0xFF4B2028)
              : const Color(0xFF182433),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!user)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  bot.title,
                  style: const TextStyle(
                    color: Color(0xFF40A7E3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isError ? const Color(0xFFFFD4D8) : Colors.white,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '10:42', // Placeholder time
                      style: TextStyle(
                        color: user ? const Color(0xFF75AEEB) : const Color(0xFF728196),
                        fontSize: 11,
                      ),
                    ),
                    if (user) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, color: Color(0xFF40A7E3), size: 14),
                    ],
                  ],
                ),
              ],
            ),
            if (message.deck != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () => onDeck(message.deck!),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始背诵'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A394C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (message.isMiniAppAction)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: onOpenMiniApp,
                  icon: const Icon(Icons.web_asset),
                  label: Text(message.actionLabel ?? '打开应用'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2A394C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
            if (message.cliTaskId != null && message.cliLogs != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF263445)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Text('执行日志', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (message.cliLogs!.isEmpty)
                      const Text('等待输出...', style: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace')),
                    ...message.cliLogs!.map((log) => Text(log, style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'monospace'))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF182433),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GlobalProgress extends StatelessWidget {
  const _GlobalProgress({required this.model});
  final FileTransferModel model;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF182433),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Text(
        model.isPreparingSend
            ? model.preparingSendMessage
            : '已传播 ${model.globalSentCount} 个节点 · ${model.globalDataSentMB.toStringAsFixed(2)} MB',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF253A52) : const Color(0xFF172432),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFF3F8FE5) : const Color(0xFF263445),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9EC7FF), size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF91A3B7),
              size: 16,
            ),
        ],
      ),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: selected
          ? const Color(0xFF3390EC)
          : const Color(0xFF253445),
      child: Icon(icon, color: Colors.white),
    ),
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
    subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF91A3B7))),
    trailing: selected
        ? const Icon(Icons.check_circle, color: Color(0xFF4DDE7A))
        : null,
  );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.children, this.maxHeightFactor});
  final List<Widget> children;
  final double? maxHeightFactor;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      constraints: maxHeightFactor == null
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor!,
            ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF6E7F92),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
