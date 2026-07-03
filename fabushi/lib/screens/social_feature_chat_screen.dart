import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_model.dart';
import '../features/flashcards/domain/flashcard_models.dart';
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
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  static final Map<String, List<_ChatMessage>> _sharedMessages = {};
  static final Map<String, _MiniAppSession> _sharedMiniAppSessions = {};
  static final Map<String, _RuntimeDeliverySummary> _sharedDeliverySummaries =
      {};

  final Map<String, List<_ChatMessage>> _messages = _sharedMessages;
  final Map<String, _MiniAppSession> _miniAppSessions = _sharedMiniAppSessions;
  final Map<String, String> _cliTaskBotIds = {};
  final Set<String> _gdLiveTaskIds = {};
  final Map<String, List<Map<String, dynamic>>> _miniAppCommandCache = {};
  final Map<String, String> _miniAppInputHints = {};
  final Map<String, _RuntimeDeliverySummary> _deliverySummaries =
      _sharedDeliverySummaries;
  final http.Client _httpClient = http.Client();
  final Set<DharmaPublishPlatform> _platforms = {
    DharmaPublishPlatform.xiaohongshu,
  };
  FlashcardCreationMode _flashcardMode = FlashcardCreationMode.randomCloze;
  bool _busy = false;
  String _activity = '';
  bool _miniAppPanelOpen = false;
  String? _visibleMiniAppKey;

  SocialFeatureBot get _bot => widget.bot;
  MiniAppBotKind get _kind => widget.bot.effectiveKind;
  List<_ChatMessage> get _botMessages =>
      _messages.putIfAbsent(widget.bot.stableBotId, () => []);

  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(_handleComposerFocusChanged);
    _ensureGreeting(widget.bot);
  }

  @override
  void didUpdateWidget(covariant SocialFeatureChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bot.stableBotId != widget.bot.stableBotId) {
      _composer.clear();
      _miniAppPanelOpen = false;
      _visibleMiniAppKey = null;
      _ensureGreeting(widget.bot);
      _scrollBottom();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    _composerFocus
      ..removeListener(_handleComposerFocusChanged)
      ..dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _handleComposerFocusChanged() {
    if (mounted) setState(() {});
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
        final sessions = _orderedMiniAppSessions();

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
            for (var i = 0; i < sessions.length; i++)
              _buildMiniAppSessionHost(
                sessions[i],
                index: i,
                constraints: constraints,
                wide: wide,
              ),
          ],
        );
      },
    );
  }

  List<_MiniAppSession> _orderedMiniAppSessions() {
    final sessions = _miniAppSessions.values.toList(growable: false);
    sessions.sort((a, b) {
      final aVisible = a.key == _visibleMiniAppKey;
      final bVisible = b.key == _visibleMiniAppKey;
      if (aVisible == bVisible) return 0;
      return aVisible ? 1 : -1;
    });
    return sessions;
  }

  Widget _buildMiniAppSessionHost(
    _MiniAppSession session, {
    required int index,
    required BoxConstraints constraints,
    required bool wide,
  }) {
    assert(index >= 0);
    final visible = _miniAppPanelOpen && session.key == _visibleMiniAppKey;
    final compactTop = constraints.maxHeight * 0.14;

    // 不把后台小程序移出屏幕。macOS/桌面端 PlatformView/WebView 在被移出可见区域后，
    // 再回到前台时可能重新挂载，导致 React 内存态日志丢失，看起来像“新小程序”。
    // 保持同一个 WebView 在原位置，只做透明和 IgnorePointer，打开时就是刚刚后台调用的实例。
    return Positioned(
      key: ValueKey('miniapp-position:${session.key}'),
      top: wide ? 0 : compactTop,
      bottom: 0,
      right: 0,
      left: wide ? null : 0,
      width: wide ? 430 : null,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0.001,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _MiniAppHostFrame(
            wide: wide,
            child: MiniAppHostScreen(
              key: ValueKey('miniapp-session:${session.key}'),
              bot: session.bot,
              inline: true,
              onMinimize: _hideMiniAppPanel,
              onClose: _closeVisibleMiniAppSession,
              startParam: session.startParam,
              reloadToken: session.startParamVersion == 0
                  ? null
                  : session.startParamVersion.toString(),
              controller: session.controller,
              onMiniAppEvent: _handleMiniAppEvent,
              onComposerStateRequest: () => _composerStateFor(session.bot),
              onCliStart: (title, taskId) => _handleMiniAppCliStart(
                session.bot.stableBotId,
                title,
                taskId,
              ),
              onCliLog: _handleMiniAppCliLog,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FileTransferModel model) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final buttonSize = compact ? 40.0 : 48.0;
        final horizontalPadding = compact ? 10.0 : 22.0;
        final avatarRadius = compact ? 20.0 : 24.0;

        Widget headerIcon({
          required String tooltip,
          required IconData icon,
          required VoidCallback? onPressed,
        }) {
          return IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: const Color(0xFF91A3B7)),
            iconSize: compact ? 22 : 24,
            splashRadius: compact ? 20 : 24,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: buttonSize,
              height: buttonSize,
            ),
          );
        }

        return Container(
          height: compact ? 64 : 74,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: const BoxDecoration(
            color: Color(0xFF17212B),
            border: Border(bottom: BorderSide(color: Color(0xFF223040))),
          ),
          child: Row(
            children: [
              if (Navigator.of(context).canPop())
                headerIcon(
                  tooltip: '返回',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: _bot.avatarColor,
                child: Icon(
                  _bot.icon,
                  color: Colors.white,
                  size: compact ? 22 : 24,
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText(model),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        color: Color(0xFF91A3B7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                headerIcon(tooltip: '搜索', icon: Icons.search, onPressed: () {}),
                headerIcon(
                  tooltip: '拨打电话',
                  icon: Icons.call_outlined,
                  onPressed: () {},
                ),
              ],
              headerIcon(
                tooltip: _miniAppPanelOpen ? '关闭侧栏' : '打开侧栏',
                icon: _miniAppPanelOpen ? Icons.web_asset_off : Icons.web_asset,
                onPressed: _toggleMiniAppPanel,
              ),
              if (compact)
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: PopupMenuButton<String>(
                    tooltip: '更多选项',
                    color: const Color(0xFF17212B),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, color: Color(0xFF91A3B7)),
                    onSelected: (value) {
                      if (value == 'settings') _openCurrentSettings(model);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'search',
                        child: Text(
                          '搜索',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'call',
                        child: Text(
                          '拨打电话',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Text(
                          '更多选项',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              else
                headerIcon(
                  tooltip: '更多选项',
                  icon: Icons.more_vert,
                  onPressed: () => _openCurrentSettings(model),
                ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(FileTransferModel model) {
    switch (_kind) {
      case MiniAppBotKind.globalDharma:
        final summary = _deliverySummaries[_bot.stableBotId];
        if (summary != null && summary.hasActivity) return summary.statusLine;
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
          onTap: _toggleMiniAppPanel,
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
          return _MessageBubble(message: _botMessages[index], bot: _bot);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
        final inputActive = _composerFocus.hasFocus || keyboardVisible;
        final collapseMiniAppButton = compact && hasMiniApp && inputActive;
        final splitControls =
            compact && hasMiniApp && !inputActive && constraints.maxWidth < 380;
        final horizontalPadding = compact ? 12.0 : 20.0;
        final bottomPadding = inputActive ? 8.0 : (compact ? 12.0 : 18.0);

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 8 : 10,
            horizontalPadding,
            bottomPadding,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF17212B),
            border: Border(top: BorderSide(color: Color(0xFF223040))),
          ),
          child: splitControls
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildOpenMiniAppButton(
                            compact: true,
                            collapsed: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildComposerIconButton(
                          tooltip: '命令与附件',
                          icon: Icons.add,
                          onPressed: () => _openPlusMenu(model),
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildComposerTextField(
                            model,
                            canSend,
                            compact: true,
                            inputActive: inputActive,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSubmitOrVoiceButton(
                          model,
                          canSend,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasMiniApp)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 2),
                        child: _buildOpenMiniAppButton(
                          compact: compact,
                          collapsed: collapseMiniAppButton,
                        ),
                      ),
                    _buildComposerIconButton(
                      tooltip: '命令与附件',
                      icon: Icons.add,
                      onPressed: () => _openPlusMenu(model),
                      compact: compact,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildComposerTextField(
                        model,
                        canSend,
                        compact: compact,
                        inputActive: inputActive,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildSubmitOrVoiceButton(model, canSend, compact: compact),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildOpenMiniAppButton({
    required bool compact,
    required bool collapsed,
  }) {
    final height = compact ? 44.0 : 46.0;
    final borderRadius = BorderRadius.circular(compact ? 14 : 16);
    final style = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF40A7E3),
      foregroundColor: Colors.white,
      minimumSize: Size(0, height),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 10,
      ),
      elevation: 0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: collapsed ? height : null,
      height: height,
      child: collapsed
          ? ElevatedButton(
              onPressed: () => _openMiniAppPanel(),
              style: style.copyWith(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              child: Icon(Icons.web_asset, size: compact ? 22 : 24),
            )
          : ElevatedButton.icon(
              onPressed: () => _openMiniAppPanel(),
              style: style,
              icon: Icon(Icons.web_asset, size: compact ? 18 : 20),
              label: Text(
                '打开应用',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 15,
                ),
              ),
            ),
    );
  }

  Widget _buildComposerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool compact,
    Color color = const Color(0xFF91A3B7),
  }) {
    final size = compact ? 42.0 : 48.0;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      splashRadius: compact ? 20 : 24,
      icon: Icon(icon, color: color, size: compact ? 26 : 28),
    );
  }

  Widget _buildSubmitOrVoiceButton(
    FileTransferModel model,
    bool canSend, {
    required bool compact,
  }) {
    if (canSend) {
      return _buildComposerIconButton(
        tooltip: '发送',
        icon: _busy ? Icons.more_horiz : Icons.send,
        onPressed: () => _submit(model),
        compact: compact,
        color: const Color(0xFF40A7E3),
      );
    }
    return _buildComposerIconButton(
      tooltip: '语音留言',
      icon: Icons.mic_none,
      onPressed: () {},
      compact: compact,
    );
  }

  Widget _buildComposerTextField(
    FileTransferModel model,
    bool canSend, {
    required bool compact,
    required bool inputActive,
  }) {
    return TextField(
      controller: _composer,
      focusNode: _composerFocus,
      enabled: !_busy,
      minLines: 1,
      maxLines: compact ? 4 : 5,
      textInputAction: TextInputAction.send,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 15 : 16,
        height: 1.35,
      ),
      decoration: InputDecoration(
        hintText: _composerHint(compact, inputActive: inputActive),
        hintMaxLines: 1,
        hintStyle: TextStyle(
          color: const Color(0xFF6E7F92),
          fontSize: compact ? 15 : 16,
          overflow: TextOverflow.ellipsis,
        ),
        isDense: compact,
        filled: true,
        fillColor: const Color(0xFF17212B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 20 : 22),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 9 : 10,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: compact
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.sentiment_satisfied_alt,
                  color: Color(0xFF91A3B7),
                ),
                onPressed: () {},
              ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (canSend) _submit(model);
      },
    );
  }

  String _composerHint(bool compact, {required bool inputActive}) {
    final inputHint =
        _miniAppInputHints[_bot.stableBotId]?.trim().isNotEmpty == true
        ? _miniAppInputHints[_bot.stableBotId]!.trim()
        : _bot.inputHint;
    if (compact && inputActive) return '输入消息';
    if (!compact || inputHint.length <= 14) return inputHint;
    return switch (_kind) {
      MiniAppBotKind.globalDharma => '输入文字/链接，或点 + 添加素材',
      MiniAppBotKind.flashcards => '粘贴正文或链接',
      MiniAppBotKind.platformPublish => '输入发布正文/链接',
      MiniAppBotKind.botFather => '描述想创建的小程序',
      MiniAppBotKind.assistant || MiniAppBotKind.thirdParty => inputHint,
    };
  }

  Map<String, dynamic> _composerStateFor(SocialFeatureBot bot) {
    final hint = _miniAppInputHints[bot.stableBotId]?.trim().isNotEmpty == true
        ? _miniAppInputHints[bot.stableBotId]!.trim()
        : bot.inputHint;
    return {
      'text': bot.stableBotId == _bot.stableBotId ? _composer.text : '',
      'placeholder': hint,
      'commands': _miniAppCommandCache[bot.stableBotId] ?? const [],
    };
  }

  Future<void> _openPlusMenu(FileTransferModel model) async {
    final commands = await _loadMiniAppCommands();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17212B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _MiniAppCommandSheet(
        bot: _bot,
        commands: commands,
        onOpenApp: () {
          Navigator.pop(sheetContext);
          _openMiniAppPanel();
        },
        onSelectCommand: (command) {
          Navigator.pop(sheetContext);
          _insertCommandIntoComposer(command);
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMiniAppCommands() async {
    final cached = _miniAppCommandCache[_bot.stableBotId];
    if (cached != null && cached.isNotEmpty) return cached;
    if (_bot.miniAppId?.trim().isNotEmpty != true) return const [];
    try {
      final session = await _ensureMiniAppSession(_bot);
      final commands = await session.controller.getCommands();
      if (mounted) {
        setState(() => _miniAppCommandCache[_bot.stableBotId] = commands);
      }
      return commands;
    } catch (_) {
      return const [];
    }
  }

  void _insertCommandIntoComposer(Map<String, dynamic> command) {
    final rawCommand = command['command']?.toString().trim() ?? '';
    if (rawCommand.isEmpty) return;
    final text = rawCommand.startsWith('/') ? rawCommand : '/$rawCommand';
    _composer.text = '$text ';
    _composer.selection = TextSelection.collapsed(
      offset: _composer.text.length,
    );
    setState(() {});
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
    if (_shouldRouteMessageToMiniApp) {
      unawaited(_startMiniAppCommand());
      return;
    }

    switch (_kind) {
      case MiniAppBotKind.botFather:
        unawaited(_startBotFather());
        return;
      case MiniAppBotKind.assistant:
        unawaited(_startGenericBotChat());
        return;
      case MiniAppBotKind.globalDharma:
      case MiniAppBotKind.flashcards:
      case MiniAppBotKind.platformPublish:
      case MiniAppBotKind.thirdParty:
        unawaited(_startMiniAppCommand());
        return;
    }
  }

  bool get _shouldRouteMessageToMiniApp {
    final hasMiniApp = _bot.miniAppId?.trim().isNotEmpty == true;
    if (!hasMiniApp) return false;
    return switch (_kind) {
      MiniAppBotKind.globalDharma ||
      MiniAppBotKind.flashcards ||
      MiniAppBotKind.platformPublish ||
      MiniAppBotKind.thirdParty => true,
      MiniAppBotKind.botFather || MiniAppBotKind.assistant => false,
    };
  }

  Future<void> _startMiniAppCommand() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    setState(() {
      _botMessages.add(_ChatMessage.user(text));
      _busy = true;
      _activity = '正在调用 ${_bot.title}...';
    });
    _scrollBottom();

    try {
      final session = await _ensureMiniAppSession(_bot);
      final wasForeground =
          _miniAppPanelOpen && _visibleMiniAppKey == session.key;
      final result = await session.controller.runCommand(text);
      session
        ..lastCommandAt = DateTime.now()
        ..lastCommandText = text;
      if (!mounted) return;
      setState(() {
        _botMessages.add(
          _ChatMessage.bot(
            wasForeground
                ? '已发送给当前打开的「${_bot.title}」，由小程序执行。\n命令：${result['command'] ?? '/start'}'
                : '已发送给后台运行的「${_bot.title}」，由小程序执行。\n点击「打开应用」会回到同一个小程序实例。\n命令：${result['command'] ?? '/start'}',
          ),
        );
      });
    } catch (e) {
      if (mounted) _botMessages.add(_ChatMessage.error('调用失败：$e'));
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

  Future<_MiniAppSession> _ensureMiniAppSession(
    SocialFeatureBot bot, {
    String? startParam,
  }) async {
    final key = _miniAppSessionKey(bot);
    var session = _miniAppSessions[key];
    if (session == null) {
      session = _MiniAppSession(
        key: key,
        bot: bot,
        startParam: startParam,
        controller: MiniAppHostController(),
      );
      setState(() => _miniAppSessions[key] = session!);
      await WidgetsBinding.instance.endOfFrame;
    } else {
      if (startParam != null) {
        setState(() {
          session!
            ..bot = bot
            ..startParam = startParam
            ..startParamVersion += 1;
        });
        await WidgetsBinding.instance.endOfFrame;
      } else {
        session.bot = bot;
      }
    }
    return session;
  }

  String _miniAppSessionKey(SocialFeatureBot bot) {
    return '${bot.stableBotId}:${bot.stableMiniAppId}';
  }

  void _handleMiniAppEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString() ?? '';
    final botId = event['botId']?.toString().trim() ?? _bot.stableBotId;

    if (type == 'bot.commandsChanged') {
      final rawCommands = event['commands'];
      final commands = rawCommands is List
          ? rawCommands
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : <Map<String, dynamic>>[];
      setState(() => _miniAppCommandCache[botId] = commands);
      return;
    }

    if (type == 'bot.composer.placeholder') {
      final placeholder = event['placeholder']?.toString().trim() ?? '';
      setState(() => _miniAppInputHints[botId] = placeholder);
      return;
    }

    if (type == 'bot.composer.text') {
      if (botId == _bot.stableBotId) {
        final value = event['text']?.toString() ?? '';
        _composer.text = event['append'] == true
            ? _composer.text + value
            : value;
        _composer.selection = TextSelection.collapsed(
          offset: _composer.text.length,
        );
        setState(() {});
      }
      return;
    }

    if (type == 'runtime.update') {
      _handleRuntimeUpdate(botId, event);
      return;
    }

    final text = event['text']?.toString().trim() ?? '';
    if (text.isEmpty) return;
    final isError = event['isError'] == true || event['level'] == 'error';
    final updateKey = event['updateKey']?.toString().trim();
    final replaceLast = event['replaceLast'] == true;
    setState(() {
      final messages = _messages.putIfAbsent(botId, () => []);
      _ChatMessage? existing;
      if (updateKey != null && updateKey.isNotEmpty) {
        for (final msg in messages.reversed) {
          if (msg.updateKey == updateKey) {
            existing = msg;
            break;
          }
        }
      } else if (replaceLast && messages.isNotEmpty) {
        for (final msg in messages.reversed) {
          if (!msg.isUser && msg.cliTaskId == null) {
            existing = msg;
            break;
          }
        }
      }
      if (existing != null) {
        existing.text = text;
        existing.isError = isError;
      } else {
        messages.add(
          isError
              ? _ChatMessage.error(text, updateKey: updateKey)
              : _ChatMessage.bot(text, updateKey: updateKey),
        );
      }
    });
    if (botId == _bot.stableBotId) _scrollBottom();
  }

  void _handleRuntimeUpdate(String botId, Map<String, dynamic> event) {
    final raw = event['event'];
    if (raw is! Map) return;
    final runtimeEvent = Map<String, dynamic>.from(raw);
    final runtimeType = runtimeEvent['@type']?.toString() ?? '';
    if (!runtimeType.startsWith('updateGlobalDharma') &&
        runtimeType != 'updateFile' &&
        !runtimeType.startsWith('updateLocalStore')) {
      return;
    }
    final summary = _deliverySummaries.putIfAbsent(
      botId,
      () => _RuntimeDeliverySummary(),
    );
    summary.apply(runtimeType, runtimeEvent);
    setState(() {});
  }

  void _handleMiniAppCliStart(String botId, String title, String taskId) {
    if (!mounted) return;
    _cliTaskBotIds[taskId] = botId;
    if (title.contains('全球法布施') ||
        title.contains('Global Dharma') ||
        taskId.startsWith('gd_worker_')) {
      _gdLiveTaskIds.add(taskId);
      return;
    }
    setState(() {
      final messages = _messages.putIfAbsent(botId, () => []);
      messages.add(_ChatMessage.cliTask(title, taskId));
    });
    if (botId == _bot.stableBotId) _scrollBottom();
  }

  void _handleMiniAppCliLog(String taskId, String data) {
    if (!mounted) return;
    final botId = _cliTaskBotIds[taskId];
    if (_gdLiveTaskIds.contains(taskId)) {
      if (botId != null &&
          (data.contains('endpointId') || data.contains('nodeId'))) {
        final match = RegExp(
          r'"(?:endpointId|nodeId)"\s*:\s*"([^"]+)"',
        ).firstMatch(data);
        if (match != null) {
          final endpoint = match.group(1);
          setState(() {
            final messages = _messages[botId];
            if (messages != null) {
              for (final msg in messages.reversed) {
                if (msg.updateKey == 'gd_live_status' ||
                    (!msg.isUser && msg.cliTaskId == null)) {
                  msg.text = '🌍 全球法布施实时投递中：正在向 $endpoint 发送 UDP 数据报文...';
                  break;
                }
              }
            }
          });
        }
      }
      return;
    }
    setState(() {
      _ChatMessage? message;
      final candidateLists = botId == null
          ? _messages.values
          : [_messages.putIfAbsent(botId, () => [])];
      for (final list in candidateLists) {
        for (final item in list) {
          if (item.cliTaskId == taskId) message = item;
        }
      }
      final logs = message?.cliLogs;
      if (logs == null) return;
      logs.addAll(
        data.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty),
      );
      if (logs.length > 160) {
        logs.removeRange(0, logs.length - 160);
      }
    });
    if (_cliTaskBotIds[taskId] == _bot.stableBotId) _scrollBottom();
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

  void _toggleMiniAppPanel() {
    if (_miniAppPanelOpen) {
      _hideMiniAppPanel();
    } else {
      _openMiniAppPanel();
    }
  }

  void _hideMiniAppPanel() {
    setState(() => _miniAppPanelOpen = false);
  }

  void _openMiniAppPanel([SocialFeatureBot? bot, String? startParam]) {
    unawaited(_showMiniAppPanel(bot, startParam));
  }

  Future<void> _showMiniAppPanel([
    SocialFeatureBot? bot,
    String? startParam,
  ]) async {
    final session = await _ensureMiniAppSession(
      bot ?? _bot,
      startParam: startParam,
    );
    if (!mounted) return;
    setState(() {
      _visibleMiniAppKey = session.key;
      _miniAppPanelOpen = true;
    });
  }

  void _closeVisibleMiniAppSession() {
    final key = _visibleMiniAppKey;
    if (key == null) {
      _hideMiniAppPanel();
      return;
    }
    setState(() {
      _miniAppSessions.remove(key);
      _visibleMiniAppKey = null;
      _miniAppPanelOpen = false;
    });
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
    this.cliTaskId,
    this.cliLogs,
    this.updateKey,
  });
  String text;
  final bool isUser;
  bool isError;
  final String? cliTaskId;
  List<String>? cliLogs;
  String? updateKey;

  factory _ChatMessage.user(String text) => _ChatMessage(text, isUser: true);
  factory _ChatMessage.bot(String text, {String? updateKey}) =>
      _ChatMessage(text, isUser: false, updateKey: updateKey);
  factory _ChatMessage.error(String text, {String? updateKey}) =>
      _ChatMessage(text, isUser: false, isError: true, updateKey: updateKey);
  factory _ChatMessage.cliTask(String text, String taskId) =>
      _ChatMessage(text, isUser: false, cliTaskId: taskId, cliLogs: []);
}

class _MiniAppSession {
  _MiniAppSession({
    required this.key,
    required this.bot,
    required this.controller,
    this.startParam,
  });

  final String key;
  SocialFeatureBot bot;
  final MiniAppHostController controller;
  String? startParam;
  int startParamVersion = 0;
  DateTime? lastCommandAt;
  String? lastCommandText;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.bot});
  final _ChatMessage message;
  final SocialFeatureBot bot;

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
                      color: message.isError
                          ? const Color(0xFFFFD4D8)
                          : Colors.white,
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
                        color: user
                            ? const Color(0xFF75AEEB)
                            : const Color(0xFF728196),
                        fontSize: 11,
                      ),
                    ),
                    if (user) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all,
                        color: Color(0xFF40A7E3),
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ],
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
                        Icon(
                          Icons.terminal,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '执行日志',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (message.cliLogs!.isEmpty)
                      const Text(
                        '等待输出...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ...message.cliLogs!.map(
                      (log) => Text(
                        log,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
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

class _MiniAppCommandSheet extends StatefulWidget {
  const _MiniAppCommandSheet({
    required this.bot,
    required this.commands,
    required this.onOpenApp,
    required this.onSelectCommand,
  });

  final SocialFeatureBot bot;
  final List<Map<String, dynamic>> commands;
  final VoidCallback onOpenApp;
  final ValueChanged<Map<String, dynamic>> onSelectCommand;

  @override
  State<_MiniAppCommandSheet> createState() => _MiniAppCommandSheetState();
}

class _MiniAppCommandSheetState extends State<_MiniAppCommandSheet> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _filter.text.trim().toLowerCase();
    final commands = widget.commands
        .where((command) {
          if (keyword.isEmpty) return true;
          return [command['command'], command['description'], command['title']]
              .whereType<Object>()
              .any((value) => value.toString().toLowerCase().contains(keyword));
        })
        .toList(growable: false);

    return _BottomPanel(
      maxHeightFactor: 0.72,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.bot.avatarColor,
              child: Icon(widget.bot.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bot.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    '小程序命令由小程序声明，宿主只负责展示与转发。',
                    style: TextStyle(color: Color(0xFF91A3B7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _filter,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '搜索命令或附件动作',
            hintStyle: const TextStyle(color: Color(0xFF6E7F92)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF91A3B7)),
            filled: true,
            fillColor: const Color(0xFF0F1722),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ListTile(
          onTap: widget.onOpenApp,
          leading: const Icon(Icons.web_asset, color: Color(0xFF40A7E3)),
          title: const Text('打开应用', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            '回到同一个小程序实例',
            style: TextStyle(color: Color(0xFF91A3B7)),
          ),
        ),
        if (commands.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '还没有读取到小程序命令，可先打开应用让小程序注册命令。',
              style: TextStyle(color: Color(0xFF91A3B7)),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: commands.length,
              itemBuilder: (context, index) {
                final command = commands[index];
                final name = command['command']?.toString() ?? '';
                final description = command['description']?.toString() ?? '';
                return ListTile(
                  onTap: () => widget.onSelectCommand(command),
                  leading: const Icon(Icons.bolt, color: Color(0xFF4DDE7A)),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    description.isEmpty ? '插入到输入框后可继续补充参数' : description,
                    style: const TextStyle(color: Color(0xFF91A3B7)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MiniAppHostFrame extends StatelessWidget {
  const _MiniAppHostFrame({required this.wide, required this.child});

  final bool wide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: wide
          ? const EdgeInsets.all(12)
          : const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111A),
        border: wide
            ? const Border(left: BorderSide(color: Color(0xFF223040)))
            : null,
        borderRadius: wide
            ? null
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: child,
    );
  }
}

class _RuntimeDeliverySummary {
  int jobs = 0;
  int inFlight = 0;
  int retrying = 0;
  int receipts = 0;
  int files = 0;
  String? lastFailure;

  bool get hasActivity =>
      jobs > 0 ||
      inFlight > 0 ||
      retrying > 0 ||
      receipts > 0 ||
      files > 0 ||
      lastFailure != null;

  String get statusLine {
    final parts = <String>[];
    if (jobs > 0) parts.add('job $jobs');
    if (inFlight > 0) parts.add('投递中 $inFlight');
    if (retrying > 0) parts.add('重试中 $retrying');
    if (receipts > 0) parts.add('回执 $receipts');
    if (files > 0) parts.add('文件 $files');
    if (lastFailure != null) parts.add('最近失败：$lastFailure');
    if (parts.isEmpty) return 'bot · 全球法布施内核待命';
    return 'bot · ${parts.join(' · ')}';
  }

  void apply(String runtimeType, Map<String, dynamic> event) {
    if (runtimeType == 'updateGlobalDharmaDeliveryQueued') {
      jobs += 1;
      return;
    }
    if (runtimeType == 'updateGlobalDharmaDeliveryStarted' ||
        runtimeType == 'updateGlobalDharmaDeliveryWorkerAttempting') {
      inFlight += 1;
      return;
    }
    if (runtimeType == 'updateGlobalDharmaReceiptReceived') {
      receipts += 1;
      if (inFlight > 0) inFlight -= 1;
      return;
    }
    if (runtimeType == 'updateGlobalDharmaDeliveryAttempt') {
      final status = event['status']?.toString() ?? '';
      if (inFlight > 0) inFlight -= 1;
      if (status == 'retry_scheduled') {
        retrying += 1;
      } else if (status == 'failed') {
        lastFailure = _readFailure(event);
      }
      return;
    }
    if (runtimeType == 'updateFile') {
      files += 1;
      if (event['state']?.toString() == 'failed') {
        lastFailure = _readFailure(event);
      }
      return;
    }
    if (runtimeType == 'updateGlobalDharmaDeliveryWorkerError') {
      lastFailure = event['message']?.toString();
    }
  }

  static String? _readFailure(Map<String, dynamic> event) {
    final direct = event['message']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final job = event['job'];
    if (job is Map) {
      final error = job['lastError'];
      if (error is Map) {
        final message = error['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
        final code = error['code']?.toString().trim();
        if (code != null && code.isNotEmpty) return code;
      }
      if (error != null) return error.toString();
    }
    return null;
  }
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
