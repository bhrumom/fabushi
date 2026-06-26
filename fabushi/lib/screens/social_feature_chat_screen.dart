import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<SocialFeatureBotType, List<_ChatMessage>> _messages = {};
  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  final DharmaPublishService _publishService = DharmaPublishService();
  final Set<DharmaPublishPlatform> _platforms = {DharmaPublishPlatform.xiaohongshu};
  FlashcardCreationMode _flashcardMode = FlashcardCreationMode.randomCloze;
  bool _busy = false;
  String _activity = '';

  SocialFeatureBot get _bot => widget.botType.bot;
  List<_ChatMessage> get _botMessages => _messages.putIfAbsent(widget.botType, () => []);

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
      _composer.clear();
      _ensureGreeting(widget.botType);
      _scrollBottom();
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureGreeting(SocialFeatureBotType type) {
    final list = _messages.putIfAbsent(type, () => []);
    if (list.isEmpty) list.add(_ChatMessage.bot(type.bot.greeting));
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final canSend = !_busy && _canSubmit(model);
    return ColoredBox(
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
                Text(_bot.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(_statusText(model), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF91A3B7), fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: '联系人设置',
            onPressed: () => _openCurrentSettings(model),
            icon: const Icon(Icons.tune, color: Color(0xFF91A3B7)),
          ),
        ],
      ),
    );
  }

  String _statusText(FileTransferModel model) {
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        if (model.isPreparingSend) return model.preparingSendMessage;
        return model.isTransferring ? '正在发送' : 'bot · ${model.isLooping ? "循环" : "单轮"} · ${model.isGlobalSendEnabled ? "全球" : "本地"}';
      case SocialFeatureBotType.flashcards:
        return 'bot · 当前模式：${_flashcardMode.label}';
      case SocialFeatureBotType.platformPublish:
        return 'bot · 平台：${_platformSummary()}';
      case SocialFeatureBotType.assistant:
        return 'bot';
    }
  }

  Widget _buildModeBar(FileTransferModel model) {
    final chips = switch (widget.botType) {
      SocialFeatureBotType.globalDharma => <Widget>[
          _ControlPill(icon: Icons.public, label: model.isGlobalSendEnabled ? '地区 全球' : '地区 本地', active: true, onTap: () => _showRegionSettings(model)),
          _ControlPill(icon: Icons.loop, label: model.isLooping ? '循环发送' : '单轮发送', active: model.isLooping, onTap: () { model.setLooping(!model.isLooping); setState(() {}); }),
          _ControlPill(icon: Icons.attach_file, label: model.hasFiles ? '已选素材' : '添加素材', active: model.hasFiles, onTap: () => unawaited(model.selectFiles())),
        ],
      SocialFeatureBotType.flashcards => <Widget>[
          _ControlPill(icon: _flashcardMode == FlashcardCreationMode.aiCards ? Icons.auto_awesome : Icons.auto_fix_high, label: '模式 ${_flashcardMode.label}', active: true, onTap: _showFlashcardModeSelector),
        ],
      SocialFeatureBotType.platformPublish => <Widget>[
          _ControlPill(icon: Icons.campaign_outlined, label: '平台 ${_platformSummary()}', active: true, onTap: _showPlatformSelector),
        ],
      SocialFeatureBotType.assistant => const <Widget>[
          _ControlPill(icon: Icons.smart_toy_outlined, label: '助理', active: true, onTap: null),
        ],
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: const BoxDecoration(color: Color(0xFF111B26), border: Border(bottom: BorderSide(color: Color(0xFF1F2B38)))),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _buildMessages(FileTransferModel model) {
    final showProgress = widget.botType == SocialFeatureBotType.globalDharma && (model.isPreparingSend || model.isTransferring);
    final count = _botMessages.length + (_busy ? 1 : 0) + (showProgress ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index < _botMessages.length) return _MessageBubble(message: _botMessages[index], bot: _bot, onDeck: _openDeck);
        if (_busy && index == _botMessages.length) return _ThinkingBubble(label: _activity.isEmpty ? '正在处理' : _activity);
        return _GlobalProgress(model: model);
      },
    );
  }

  Widget _buildComposer(FileTransferModel model, bool canSend) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(color: Color(0xFF17212B), border: Border(top: BorderSide(color: Color(0xFF223040)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: widget.botType == SocialFeatureBotType.flashcards ? '选择模式' : '添加素材',
            onPressed: _busy ? null : widget.botType == SocialFeatureBotType.flashcards ? _showFlashcardModeSelector : () => unawaited(model.selectFiles()),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF91A3B7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _composer,
              enabled: !_busy,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: _bot.inputHint,
                hintStyle: const TextStyle(color: Color(0xFF6E7F92)),
                filled: true,
                fillColor: const Color(0xFF101923),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF263445))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF263445))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF4F9DFF))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) { if (canSend) _submit(model); },
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: '发送',
            onPressed: canSend ? () => _submit(model) : null,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF3390EC), disabledBackgroundColor: const Color(0xFF263445)),
            icon: Icon(_busy ? Icons.more_horiz : Icons.arrow_upward, color: Colors.white),
          ),
        ],
      ),
    );
  }

  bool _canSubmit(FileTransferModel model) {
    final text = _composer.text.trim();
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        return text.isNotEmpty || model.hasFiles;
      case SocialFeatureBotType.flashcards:
        return text.isNotEmpty;
      case SocialFeatureBotType.platformPublish:
        return _platforms.isNotEmpty && (text.isNotEmpty || model.hasFiles);
      case SocialFeatureBotType.assistant:
        return text.isNotEmpty;
    }
  }

  void _submit(FileTransferModel model) {
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        unawaited(_startGlobal(model));
        return;
      case SocialFeatureBotType.flashcards:
        unawaited(_startFlashcards());
        return;
      case SocialFeatureBotType.platformPublish:
        unawaited(_startPublish(model));
        return;
      case SocialFeatureBotType.assistant:
        _addBotMessage('原有助理能力保留在 OpenClaw 工作台中。');
        return;
    }
  }

  Future<void> _startGlobal(FileTransferModel model) async {
    final text = _composer.text.trim();
    _composer.clear();
    setState(() { if (text.isNotEmpty) _botMessages.add(_ChatMessage.user(text)); _busy = true; _activity = '正在准备素材...'; });
    _scrollBottom();
    try {
      if (text.isNotEmpty) await _saveTextToModel(model, text, '全球法布施', replaceExisting: !model.hasFiles);
      if (!model.hasFiles) throw StateError('请先输入文字、链接，或点击 + 添加素材。');
      setState(() => _activity = '正在启动发送...');
      await model.startGlobalTransfer();
      if (!mounted) return;
      _botMessages.add(_ChatMessage.bot('已完成：${model.globalSentCount} 个节点，${model.globalDataSentMB.toStringAsFixed(2)} MB。'));
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('启动失败：$e'));
    } finally {
      if (mounted) setState(() { _busy = false; _activity = ''; });
      _scrollBottom();
    }
  }

  Future<void> _startFlashcards() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final progress = _ChatMessage.bot('正在准备内容...');
    setState(() { _botMessages.add(_ChatMessage.user(text)); _botMessages.add(progress); _busy = true; _activity = '正在提取正文...'; });
    _scrollBottom();
    try {
      final url = ContentPipeline.firstHttpUrl(text);
      final content = await _contentPipeline.prepare(ContentInput(text: text, url: url, title: url == null ? '背诵内容' : '链接内容'));
      if (content.isFailed) throw StateError(content.errorMessage ?? '内容提取失败');
      final auth = Provider.of<AuthModel?>(context, listen: false);
      final input = FlashcardInput(title: content.title, text: content.text, documentId: content.document?.id, sourceUrl: content.sourceUrl);
      final stream = _flashcardMode == FlashcardCreationMode.aiCards
          ? _flashcardService.generateAiCardsStream(input, token: auth?.authToken, username: auth?.currentUser?.username, isMember: auth?.hasPermission('premium') ?? false)
          : _flashcardService.generateRandomClozeStream(input);
      await for (final event in stream) {
        if (!mounted) return;
        setState(() { _activity = event.message; progress.text = event.progress > 0 ? '${event.message} (${event.progress}%)' : event.message; });
        if (event.isDone && event.deck != null) _botMessages.add(_ChatMessage.deck('制卡完成：${event.deck!.cardCount} 张 · ${event.deck!.mode.label}', event.deck!));
        if (event.isError) throw StateError(event.message);
        _scrollBottom();
      }
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('制卡失败：$e'));
    } finally {
      if (mounted) setState(() { _busy = false; _activity = ''; });
      _scrollBottom();
    }
  }

  Future<void> _startPublish(FileTransferModel model) async {
    final text = _composer.text.trim();
    _composer.clear();
    setState(() { if (text.isNotEmpty) _botMessages.add(_ChatMessage.user(text)); _busy = true; _activity = '正在生成发布草稿...'; });
    _scrollBottom();
    try {
      if (text.isNotEmpty) await _saveTextToModel(model, text, '法布施发布', replaceExisting: true);
      if (!model.hasFiles && text.isEmpty) throw StateError('请输入正文/链接，或点击 + 添加素材。');
      var draft = _publishService.buildDraftFromModel(model, fallbackText: text);
      if (draft.title.trim().isEmpty) draft = draft.copyWith(title: _publishService.suggestTitle(draft));
      if (draft.body.trim().length < 12) draft = draft.copyWith(body: _publishService.polishBody(draft));
      _botMessages.add(_ChatMessage.bot(_publishService.buildPreviewMarkdown(draft, _platforms)));
      setState(() => _activity = '正在复制草稿并打开入口...');
      final results = await _publishService.publishDraft(draft: draft, platforms: _platforms);
      if (!mounted) return;
      _botMessages.add(_ChatMessage.bot(results.map((r) => '${r.platform.info.shortLabel}：${r.message}').join('\n')));
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('发布失败：$e'));
    } finally {
      if (mounted) setState(() { _busy = false; _activity = ''; });
      _scrollBottom();
    }
  }

  Future<void> _saveTextToModel(FileTransferModel model, String text, String fallbackTitle, {required bool replaceExisting}) async {
    final uri = Uri.tryParse(text);
    final isLink = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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
    switch (widget.botType) {
      case SocialFeatureBotType.globalDharma:
        _showRegionSettings(model);
        return;
      case SocialFeatureBotType.flashcards:
        _showFlashcardModeSelector();
        return;
      case SocialFeatureBotType.platformPublish:
        _showPlatformSelector();
        return;
      case SocialFeatureBotType.assistant:
        _addBotMessage('暂无更多设置。');
        return;
    }
  }

  void _showFlashcardModeSelector() {
    showModalBottomSheet<void>(context: context, backgroundColor: Colors.transparent, builder: (ctx) => _BottomPanel(children: [
      _ModeTile(icon: Icons.auto_fix_high, title: '随机挖空', subtitle: '本地快速生成，无需 AI。', selected: _flashcardMode == FlashcardCreationMode.randomCloze, onTap: () { setState(() => _flashcardMode = FlashcardCreationMode.randomCloze); Navigator.pop(ctx); }),
      _ModeTile(icon: Icons.auto_awesome, title: 'AI 制卡', subtitle: '按要求生成问答/挖空卡。', selected: _flashcardMode == FlashcardCreationMode.aiCards, onTap: () { setState(() => _flashcardMode = FlashcardCreationMode.aiCards); Navigator.pop(ctx); }),
    ]));
  }

  Future<void> _showPlatformSelector() async {
    final selected = Set<DharmaPublishPlatform>.from(_platforms);
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSheetState) => _BottomPanel(maxHeightFactor: 0.74, children: [
        const Text('选择发布平台', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Flexible(child: ListView(children: [
          for (final platform in DharmaPublishService.allPlatforms)
            CheckboxListTile(
              value: selected.contains(platform),
              onChanged: (v) => setSheetState(() { if (v == true) { selected.add(platform); } else { selected.remove(platform); } }),
              title: Text(platform.info.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              subtitle: Text(platform.info.description, style: const TextStyle(color: Color(0xFF91A3B7))),
            ),
        ])),
        FilledButton(onPressed: selected.isEmpty ? null : () { setState(() { _platforms..clear()..addAll(selected); }); Navigator.pop(ctx); }, child: const Text('完成')),
      ]));
    });
  }

  Future<void> _showRegionSettings(FileTransferModel model) async {
    var global = model.isGlobalSendEnabled;
    var local = model.isLocalLoopbackEnabled;
    var field = model.isFieldEnergyMode;
    await showModalBottomSheet<void>(context: context, backgroundColor: Colors.transparent, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSheetState) => _BottomPanel(children: [
        const Text('全球法布施设置', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        SwitchListTile(value: global, onChanged: (v) => setSheetState(() => global = v), title: const Text('全球节点', style: TextStyle(color: Colors.white))),
        SwitchListTile(value: field, onChanged: (v) => setSheetState(() => field = v), title: const Text('本地场能', style: TextStyle(color: Colors.white))),
        SwitchListTile(value: local, onChanged: (v) => setSheetState(() => local = v), title: const Text('本地转经轮', style: TextStyle(color: Colors.white))),
        FilledButton(onPressed: () async { model.setGlobalSendEnabled(global); model.setCountryList(global ? ['ALL'] : const []); await model.setFieldEnergyMode(field); model.setLocalLoopbackEnabled(local); if (mounted) setState(() {}); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('完成')),
      ]));
    });
  }

  String _platformSummary() {
    if (_platforms.isEmpty) return '未选择';
    final labels = _platforms.map((p) => p.info.shortLabel).toList();
    return labels.length <= 2 ? labels.join('、') : '${labels.take(2).join('、')} 等 ${labels.length} 个';
  }

  void _addBotMessage(String text) { setState(() => _botMessages.add(_ChatMessage.bot(text))); _scrollBottom(); }

  void _openDeck(FlashcardDeck deck) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardStudyScreen(deck: deck, repository: _flashcardRepository)));
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }
}

class _ChatMessage {
  _ChatMessage(this.text, {required this.isUser, this.isError = false, this.deck});
  String text;
  final bool isUser;
  final bool isError;
  final FlashcardDeck? deck;
  factory _ChatMessage.user(String text) => _ChatMessage(text, isUser: true);
  factory _ChatMessage.bot(String text) => _ChatMessage(text, isUser: false);
  factory _ChatMessage.error(String text) => _ChatMessage(text, isUser: false, isError: true);
  factory _ChatMessage.deck(String text, FlashcardDeck deck) => _ChatMessage(text, isUser: false, deck: deck);
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.bot, required this.onDeck});
  final _ChatMessage message;
  final SocialFeatureBot bot;
  final ValueChanged<FlashcardDeck> onDeck;
  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF2B5278) : message.isError ? const Color(0xFF4B2028) : const Color(0xFF182433),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF263445)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (!user) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(bot.title, style: const TextStyle(color: Color(0xFF91A3B7), fontSize: 12, fontWeight: FontWeight.w800))),
          Text(message.text, style: TextStyle(color: message.isError ? const Color(0xFFFFD4D8) : Colors.white, fontSize: 15, height: 1.48, fontWeight: user ? FontWeight.w700 : FontWeight.w500)),
          if (message.deck != null) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton.icon(onPressed: () => onDeck(message.deck!), icon: const Icon(Icons.play_arrow_rounded), label: const Text('开始背诵'))),
        ]),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF182433), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF263445))), child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))])));
}

class _GlobalProgress extends StatelessWidget {
  const _GlobalProgress({required this.model});
  final FileTransferModel model;
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF182433), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF263445))), child: Text(model.isPreparingSend ? model.preparingSendMessage : '已传播 ${model.globalSentCount} 个节点 · ${model.globalDataSentMB.toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))));
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: active ? const Color(0xFF253A52) : const Color(0xFF172432), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFF3F8FE5) : const Color(0xFF263445))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFF9EC7FF), size: 17), const SizedBox(width: 7), Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)), if (onTap != null) const Icon(Icons.keyboard_arrow_down, color: Color(0xFF91A3B7), size: 16)])));
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: selected ? const Color(0xFF3390EC) : const Color(0xFF253445), child: Icon(icon, color: Colors.white)), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF91A3B7))), trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF4DDE7A)) : null);
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.children, this.maxHeightFactor});
  final List<Widget> children;
  final double? maxHeightFactor;
  @override
  Widget build(BuildContext context) => SafeArea(child: Container(constraints: maxHeightFactor == null ? null : BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor!), padding: const EdgeInsets.fromLTRB(18, 12, 18, 18), decoration: const BoxDecoration(color: Color(0xFF17212B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFF6E7F92), borderRadius: BorderRadius.circular(999)))), const SizedBox(height: 12), ...children])));
}
