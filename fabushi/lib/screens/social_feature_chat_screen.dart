import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/country_servers.dart' as country_catalog;
import '../features/auth/application/auth_model.dart';
import '../features/flashcards/application/content_pipeline.dart';
import '../features/flashcards/application/flashcard_service.dart';
import '../features/flashcards/data/flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_models.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../services/dacheng_ai_service.dart';
import '../services/dharma_publish_service.dart';
import '../widgets/social/social_feature_bot.dart';

class SocialFeatureChatScreen extends StatefulWidget {
  const SocialFeatureChatScreen({super.key, required this.botType});

  final SocialFeatureBotType botType;

  @override
  State<SocialFeatureChatScreen> createState() => _SocialFeatureChatScreenState();
}

class _SocialFeatureChatScreenState extends State<SocialFeatureChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<SocialFeatureBotType, List<_SocialChatMessage>> _messagesByBot = {};

  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  final DharmaPublishService _dharmaPublishService = DharmaPublishService();

  FlashcardCreationMode _flashcardMode = FlashcardCreationMode.randomCloze;
  final Set<DharmaPublishPlatform> _selectedPublishPlatforms = {
    DharmaPublishPlatform.xiaohongshu,
  };
  bool _isBusy = false;
  String _activityText = '';

  List<_SocialChatMessage> get _messages =>
      _messagesByBot.putIfAbsent(widget.botType, () => []);

  SocialFeatureBot get _bot => widget.botType.bot;

  @override
  void initState() {
    super.initState();
    _flashcardRepository = FlashcardRepository();
    _contentPipeline = ContentPipeline(repository: _flashcardRepository);
    _flashcardService = FlashcardService(
      repository: _flashcardRepository,
      aiService: DachengAiService(),
    );
    _ensureGreeting(widget.botType);
  }

  @override
  void didUpdateWidget(covariant SocialFeatureChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.botType != widget.botType) {
      _composerController.clear();
      _activityText = '';
      _ensureGreeting(widget.botType);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureGreeting(SocialFeatureBotType botType) {
    final list = _messagesByBot.putIfAbsent(botType, () => []);
    if (list.isNotEmpty) return;
    list.add(_SocialChatMessage.bot(botType.bot.greeting));
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final canSend = !_isBusy && _canSubmit(model);

    return Container(
      color: const Color(0xFF0F1722),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(model),
            _buildModeBar(model),
            Expanded(child: _buildMessageList(model)),
            _buildComposer(model, canSend: canSend),
          ],
        ),
      ),
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
          CircleAvatar(
            radius: 24,
            backgroundColor: _bot.avatarColor,
            child: Icon(_bot.icon, color: Colors.white, size: 25),
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
                  _statusLine(model),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF91A3B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '搜索联系人',
            onPressed: () => _appendBotNotice('请在左侧联系人栏右上角搜索并添加好友。'),
            icon: const Icon(Icons.search, color: Color(0xFF91A3B7)),
          ),
          IconButton(
            tooltip: '更多设置',
            onPressed: () => _showModeSheet(model),
            icon: const Icon(Icons.tune, color: Color(0xFF91A3B7)),
          ),
        ],
      ),
    );
  }

  String _statusLine(FileTransferModel model) {
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        if (model.isPreparingSend) return model.preparingSendMessage;
        if (model.isTransferring) return '正在全球法布施 · ${_regionSummary(model)}';
        return 'bot · ${_regionSummary(model)} · ${model.isLooping ? "循环" : "单轮"}';
      case SocialFeatureBotType.flashcards:
        return 'bot · 当前模式：${_flashcardMode.label}';
      case SocialFeatureBotType.platformPublish:
        return 'bot · 发布平台：${_platformSummary()}';
      case SocialFeatureBotType.assistant:
        return 'bot · 大乘助理';
    }
  }

  Widget _buildModeBar(FileTransferModel model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF111B26),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2B38))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: switch (widget.botType) {
          SocialFeatureBotType.globalDharma => [
              _ControlPill(
                icon: Icons.public,
                label: '地区 ${_regionSummary(model)}',
                active: true,
                onTap: _isBusy ? null : () => _showRegionSelector(model),
              ),
              _ControlPill(
                icon: Icons.loop,
                label: model.isLooping ? '循环发送' : '单轮发送',
                active: model.isLooping,
                onTap: _isBusy
                    ? null
                    : () {
                        model.setLooping(!model.isLooping);
                        setState(() {});
                      },
              ),
              _ControlPill(
                icon: Icons.folder_outlined,
                label: model.hasFiles
                    ? (model.selectedContentTitle.isEmpty
                        ? '已选择素材'
                        : model.selectedContentTitle)
                    : '添加素材',
                active: model.hasFiles,
                onTap: _isBusy ? null : () => unawaited(model.selectFiles()),
              ),
            ],
          SocialFeatureBotType.flashcards => [
              _ControlPill(
                icon: _flashcardMode == FlashcardCreationMode.aiCards
                    ? Icons.auto_awesome
                    : Icons.auto_fix_high,
                label: '模式 ${_flashcardMode.label}',
                active: true,
                onTap: _isBusy ? null : _showFlashcardModeSelector,
              ),
              _ControlPill(
                icon: Icons.help_outline,
                label: _flashcardMode == FlashcardCreationMode.aiCards
                    ? '可输入制卡要求'
                    : '本地随机挖空',
                active: false,
                onTap: null,
              ),
            ],
          SocialFeatureBotType.platformPublish => [
              _ControlPill(
                icon: Icons.campaign_outlined,
                label: '平台 ${_platformSummary()}',
                active: _selectedPublishPlatforms.isNotEmpty,
                onTap: _isBusy ? null : _showPublishPlatformSelector,
              ),
              _ControlPill(
                icon: Icons.content_paste_go_outlined,
                label: '复制草稿并打开入口',
                active: true,
                onTap: null,
              ),
            ],
          SocialFeatureBotType.assistant => [
              const _ControlPill(
                icon: Icons.smart_toy_outlined,
                label: '助理模式',
                active: true,
                onTap: null,
              ),
            ],
        },
      ),
    );
  }

  Widget _buildMessageList(FileTransferModel model) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      itemCount: _messages.length + (_isBusy ? 1 : 0) +
          (widget.botType == SocialFeatureBotType.globalDharma &&
                  (model.isPreparingSend || model.isTransferring)
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          return _MessageBubble(
            message: _messages[index],
            bot: _bot,
            onOpenDeck: _openFlashcardDeck,
          );
        }

        final busyIndex = _messages.length;
        if (_isBusy && index == busyIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ThinkingBubble(
              label: _activityText.trim().isEmpty ? '正在处理' : _activityText,
            ),
          );
        }

        return _buildGlobalProgressCard(model);
      },
    );
  }

  Widget _buildGlobalProgressCard(FileTransferModel model) {
    final successCount = model.countryStatuses
        .where((status) => status.status == SendStatus.success)
        .length;
    final total = model.countryStatuses.length;
    final label = model.isPreparingSend
        ? model.preparingSendMessage
        : model.isTransferring
            ? '正在发送：$successCount / $total'
            : '正在整理发送状态';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: const Color(0xFF182433),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3A4A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '已传播 ${model.globalSentCount} 个节点 · ${model.globalDataSentMB.toStringAsFixed(2)} MB',
              style: const TextStyle(color: Color(0xFF91A3B7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(FileTransferModel model, {required bool canSend}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(top: BorderSide(color: Color(0xFF223040))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: widget.botType == SocialFeatureBotType.flashcards
                ? '闪卡模式'
                : '添加素材',
            onPressed: _isBusy
                ? null
                : widget.botType == SocialFeatureBotType.flashcards
                    ? _showFlashcardModeSelector
                    : () => unawaited(model.selectFiles()),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF91A3B7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _composerController,
              enabled: !_isBusy,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF101923),
                hintText: _bot.inputHint,
                hintStyle: const TextStyle(color: Color(0xFF6E7F92)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF263445)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF263445)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF4F9DFF)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canSend) _submit(model);
              },
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: '发送',
            onPressed: canSend ? () => _submit(model) : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF3390EC),
              disabledBackgroundColor: const Color(0xFF263445),
            ),
            icon: Icon(
              _isBusy ? Icons.more_horiz : Icons.arrow_upward,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  bool _canSubmit(FileTransferModel model) {
    final text = _composerController.text.trim();
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        return text.isNotEmpty || model.hasFiles;
      case SocialFeatureBotType.flashcards:
        return text.isNotEmpty;
      case SocialFeatureBotType.platformPublish:
        return _selectedPublishPlatforms.isNotEmpty && (text.isNotEmpty || model.hasFiles);
      case SocialFeatureBotType.assistant:
        return text.isNotEmpty;
    }
  }

  void _submit(FileTransferModel model) {
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        unawaited(_startGlobalDharma(model));
      case SocialFeatureBotType.flashcards:
        unawaited(_startFlashcardGeneration());
      case SocialFeatureBotType.platformPublish:
        unawaited(_startPlatformPublish(model));
      case SocialFeatureBotType.assistant:
        _appendBotNotice('大乘助理仍保留在原有 OpenClaw 工作台能力中。');
    }
  }

  Future<void> _startGlobalDharma(FileTransferModel model) async {
    if (_isBusy || model.isTransferring) return;
    final text = _composerController.text.trim();
    _composerController.clear();
    setState(() {
      if (text.isNotEmpty) _messages.add(_SocialChatMessage.user(text));
      _isBusy = true;
      _activityText = '正在准备全球法布施素材...';
    });
    _scrollToBottom();

    try {
      if (text.isNotEmpty) {
        await model.addTextContentForSending(
          title: _titleFromText(text, fallback: '全球法布施'),
          text: text,
          sourceKind: '文本',
          replaceExisting: !model.hasFiles,
        );
      }
      if (!model.hasFiles) {
        throw StateError('请先输入文字/链接，或点击 + 添加素材。');
      }
      setState(() => _activityText = '正在启动全球发送...');
      await model.startGlobalTransfer();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _SocialChatMessage.bot(
            '本次全球法布施已完成：${model.globalSentCount} 个节点，${model.globalDataSentMB.toStringAsFixed(2)} MB。',
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_SocialChatMessage.error('启动失败：$error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _activityText = '';
      });
      _scrollToBottom();
    }
  }

  Future<void> _startFlashcardGeneration() async {
    if (_isBusy) return;
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    _composerController.clear();
    final progressMessage = _SocialChatMessage.bot('正在准备内容...');
    setState(() {
      _messages.add(_SocialChatMessage.user(text));
      _messages.add(progressMessage);
      _isBusy = true;
      _activityText = '正在提取正文...';
    });
    _scrollToBottom();

    try {
      final content = await _contentPipeline.prepare(
        ContentInput(
          text: text,
          url: ContentPipeline.firstHttpUrl(text),
          title: ContentPipeline.firstHttpUrl(text) == null ? '背诵内容' : '链接内容',
          sourceType: ContentPipeline.firstHttpUrl(text) == null
              ? 'composer_text'
              : 'composer_url',
        ),
      );
      if (content.isFailed) {
        throw StateError(content.errorMessage ?? '内容提取失败');
      }

      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final input = FlashcardInput(
        title: content.title,
        text: content.text,
        documentId: content.document?.id,
        sourceUrl: content.sourceUrl,
      );
      final stream = _flashcardMode == FlashcardCreationMode.aiCards
          ? _flashcardService.generateAiCardsStream(
              input,
              token: authModel?.authToken,
              username: authModel?.currentUser?.username,
              isMember: authModel?.hasPermission('premium') ?? false,
            )
          : _flashcardService.generateRandomClozeStream(input);

      await for (final event in stream) {
        if (!mounted) return;
        setState(() {
          _activityText = event.message;
          progressMessage.text = event.progress > 0
              ? '${event.message} (${event.progress}%)'
              : event.message;
        });
        _scrollToBottom();
        if (event.isDone && event.deck != null) {
          setState(() {
            _messages.add(
              _SocialChatMessage.deck(
                '制卡完成：${event.deck!.cardCount} 张 · ${event.deck!.mode.label}',
                event.deck!,
              ),
            );
          });
        }
        if (event.isError) {
          throw StateError(event.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_SocialChatMessage.error('制卡失败：$error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _activityText = '';
      });
      _scrollToBottom();
    }
  }

  Future<void> _startPlatformPublish(FileTransferModel model) async {
    if (_isBusy) return;
    final text = _composerController.text.trim();
    _composerController.clear();
    setState(() {
      if (text.isNotEmpty) _messages.add(_SocialChatMessage.user(text));
      _isBusy = true;
      _activityText = '正在整理发布草稿...';
    });
    _scrollToBottom();

    try {
      if (text.isNotEmpty) {
        final uri = Uri.tryParse(text);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          await model.addUrlContentForSending(text);
        } else {
          await model.addTextContentForSending(
            title: _titleFromText(text, fallback: '法布施发布'),
            text: text,
            sourceKind: '文本',
            replaceExisting: true,
          );
        }
      }
      if (!model.hasFiles && text.isEmpty) {
        throw StateError('请先输入要发布的文字/链接，或点击 + 添加素材。');
      }

      var draft = _dharmaPublishService.buildDraftFromModel(
        model,
        fallbackText: text,
      );
      if (draft.title.trim().isEmpty) {
        draft = draft.copyWith(title: _dharmaPublishService.suggestTitle(draft));
      }
      if (draft.body.trim().length < 12) {
        draft = draft.copyWith(body: _dharmaPublishService.polishBody(draft));
      }

      setState(() {
        _messages.add(
          _SocialChatMessage.bot(
            _dharmaPublishService.buildPreviewMarkdown(
              draft,
              _selectedPublishPlatforms,
            ),
          ),
        );
        _activityText = '正在复制草稿并打开平台入口...';
      });

      final results = await _dharmaPublishService.publishDraft(
        draft: draft,
        platforms: _selectedPublishPlatforms,
      );
      if (!mounted) return;
      final summary = results
          .map((result) => '${result.platform.info.shortLabel}：${result.message}')
          .join('\n');
      setState(() => _messages.add(_SocialChatMessage.bot(summary)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_SocialChatMessage.error('发布失败：$error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _activityText = '';
      });
      _scrollToBottom();
    }
  }

  String _titleFromText(String text, {required String fallback}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 18 ? normalized : normalized.substring(0, 18);
  }

  void _appendBotNotice(String text) {
    setState(() => _messages.add(_SocialChatMessage.bot(text)));
    _scrollToBottom();
  }

  void _showModeSheet(FileTransferModel model) {
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        unawaited(_showRegionSelector(model));
      case SocialFeatureBotType.flashcards:
        _showFlashcardModeSelector();
      case SocialFeatureBotType.platformPublish:
        unawaited(_showPublishPlatformSelector());
      case SocialFeatureBotType.assistant:
        _appendBotNotice('暂无更多设置。');
    }
  }

  void _showFlashcardModeSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF17212B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 8),
                _ModeTile(
                  icon: Icons.auto_fix_high,
                  title: '随机挖空',
                  subtitle: '本地快速生成，无需 AI。',
                  selected: _flashcardMode == FlashcardCreationMode.randomCloze,
                  onTap: () {
                    setState(() => _flashcardMode = FlashcardCreationMode.randomCloze);
                    Navigator.pop(sheetContext);
                  },
                ),
                _ModeTile(
                  icon: Icons.auto_awesome,
                  title: 'AI 制卡',
                  subtitle: '按要求生成问答/挖空卡，失败会自动回退。',
                  selected: _flashcardMode == FlashcardCreationMode.aiCards,
                  onTap: () {
                    setState(() => _flashcardMode = FlashcardCreationMode.aiCards);
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPublishPlatformSelector() async {
    final selected = Set<DharmaPublishPlatform>.from(_selectedPublishPlatforms);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF17212B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _SheetHandle()),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '选择发布平台',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            selected
                              ..clear()
                              ..addAll(DharmaPublishService.allPlatforms);
                          }),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(selected.clear),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final platform in DharmaPublishService.allPlatforms)
                            CheckboxListTile(
                              value: selected.contains(platform),
                              onChanged: (value) => setSheetState(() {
                                if (value == true) {
                                  selected.add(platform);
                                } else {
                                  selected.remove(platform);
                                }
                              }),
                              activeColor: const Color(0xFF3390EC),
                              checkColor: Colors.white,
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _selectedPublishPlatforms
                                    ..clear()
                                    ..addAll(selected);
                                });
                                Navigator.pop(sheetContext);
                              },
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRegionSelector(FileTransferModel model) async {
    final selectedCountries = Set<String>.from(model.countryList);
    var globalEnabled = model.isGlobalSendEnabled;
    var fieldEnergy = model.isFieldEnergyMode;
    var localLoopback = model.isLocalLoopbackEnabled;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF17212B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _SheetHandle()),
                    const SizedBox(height: 14),
                    const Text(
                      '全球法布施设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: globalEnabled,
                      onChanged: (value) => setSheetState(() => globalEnabled = value),
                      title: const Text('全球/国家节点', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('开启后可选择全部国家或指定国家', style: TextStyle(color: Color(0xFF91A3B7))),
                    ),
                    SwitchListTile(
                      value: fieldEnergy,
                      onChanged: (value) => setSheetState(() => fieldEnergy = value),
                      title: const Text('本地场能', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('无网场景下使用本地广播', style: TextStyle(color: Color(0xFF91A3B7))),
                    ),
                    SwitchListTile(
                      value: localLoopback,
                      onChanged: (value) => setSheetState(() => localLoopback = value),
                      title: const Text('本地转经轮', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('在本机持续运行回环法布施', style: TextStyle(color: Color(0xFF91A3B7))),
                    ),
                    const Divider(color: Color(0xFF263445)),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setSheetState(() {
                            selectedCountries
                              ..clear()
                              ..add('ALL');
                          }),
                          child: const Text('全球'),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(selectedCountries.clear),
                          child: const Text('清空国家'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final entry in _countryOptions)
                            CheckboxListTile(
                              value: selectedCountries.contains('ALL') ||
                                  selectedCountries.contains(entry.key),
                              onChanged: selectedCountries.contains('ALL')
                                  ? null
                                  : (value) => setSheetState(() {
                                        if (value == true) {
                                          selectedCountries.add(entry.key);
                                        } else {
                                          selectedCountries.remove(entry.key);
                                        }
                                      }),
                              title: Text(entry.value, style: const TextStyle(color: Colors.white)),
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          model.setGlobalSendEnabled(globalEnabled);
                          model.setCountryList(selectedCountries.toList());
                          await model.setFieldEnergyMode(fieldEnergy);
                          model.setLocalLoopbackEnabled(localLoopback);
                          if (mounted) setState(() {});
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<MapEntry<String, String>> get _countryOptions {
    final entries = country_catalog.GLOBAL_COUNTRY_SERVERS.keys
        .map((code) => MapEntry(code, country_catalog.COUNTRY_NAMES[code] ?? code))
        .toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  String _regionSummary(FileTransferModel model) {
    final labels = <String>[];
    if (model.isGlobalSendEnabled && model.countryList.isNotEmpty) {
      if (model.countryList.contains('ALL')) {
        labels.add('全球');
      } else {
        final names = model.countryList
            .map((code) => country_catalog.COUNTRY_NAMES[code] ?? code)
            .take(2)
            .toList();
        labels.add(model.countryList.length > 2
            ? '${names.join('、')} 等 ${model.countryList.length} 个'
            : names.join('、'));
      }
    }
    if (model.isFieldEnergyMode) labels.add('本地场能');
    if (model.isLocalLoopbackEnabled) labels.add('本地转经轮');
    return labels.isEmpty ? '未选择' : labels.join('、');
  }

  String _platformSummary() {
    if (_selectedPublishPlatforms.isEmpty) return '未选择';
    final labels = _selectedPublishPlatforms.map((p) => p.info.shortLabel).toList();
    if (labels.length <= 2) return labels.join('、');
    return '${labels.take(2).join('、')} 等 ${labels.length} 个';
  }

  void _openFlashcardDeck(FlashcardDeck deck) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardStudyScreen(
          deck: deck,
          repository: _flashcardRepository,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _SocialChatMessage {
  _SocialChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.deck,
  });

  String text;
  final bool isUser;
  final bool isError;
  final FlashcardDeck? deck;

  factory _SocialChatMessage.user(String text) =>
      _SocialChatMessage(text: text, isUser: true);
  factory _SocialChatMessage.bot(String text) =>
      _SocialChatMessage(text: text, isUser: false);
  factory _SocialChatMessage.error(String text) =>
      _SocialChatMessage(text: text, isUser: false, isError: true);
  factory _SocialChatMessage.deck(String text, FlashcardDeck deck) =>
      _SocialChatMessage(text: text, isUser: false, deck: deck);
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.bot,
    required this.onOpenDeck,
  });

  final _SocialChatMessage message;
  final SocialFeatureBot bot;
  final ValueChanged<FlashcardDeck> onOpenDeck;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2B5278)
              : message.isError
                  ? const Color(0xFF4B2028)
                  : const Color(0xFF182433),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: Border.all(
            color: message.isError ? const Color(0xFF7A3340) : const Color(0xFF263445),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: bot.avatarColor,
                      child: Icon(bot.icon, color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      bot.title,
                      style: const TextStyle(
                        color: Color(0xFF91A3B7),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: message.isError ? const Color(0xFFFFD4D8) : Colors.white,
                fontSize: 15,
                height: 1.48,
                fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (message.deck != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onOpenDeck(message.deck!),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始背诵'),
              ),
            ],
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
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
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
  Widget build(BuildContext context) {
    return InkWell(
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
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF91A3B7), size: 16),
            ],
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: selected ? const Color(0xFF3390EC) : const Color(0xFF253445),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF91A3B7))),
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF4DDE7A)) : null,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF6E7F92),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
