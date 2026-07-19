import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mini_app_model.dart';
import '../services/project_service.dart';

enum CodexComposerMentionKind { bot, plugin, skill, mcp }

class CodexComposerMention {
  const CodexComposerMention({
    required this.id,
    required this.label,
    required this.description,
    required this.insertText,
    required this.pluginId,
    required this.kind,
  });

  final String id;
  final String label;
  final String description;
  final String insertText;
  final String pluginId;
  final CodexComposerMentionKind kind;

  String get kindLabel => switch (kind) {
    CodexComposerMentionKind.bot => '机器人',
    CodexComposerMentionKind.plugin => '插件',
    CodexComposerMentionKind.skill => 'Skill',
    CodexComposerMentionKind.mcp => 'MCP',
  };

  IconData get icon => switch (kind) {
    CodexComposerMentionKind.bot => Icons.smart_toy_outlined,
    CodexComposerMentionKind.plugin => Icons.extension_outlined,
    CodexComposerMentionKind.skill => Icons.auto_awesome_outlined,
    CodexComposerMentionKind.mcp => Icons.hub_outlined,
  };
}

List<CodexComposerMention> buildCodexComposerMentions(
  MiniAppRegistry registry,
) {
  final mentions = <CodexComposerMention>[];
  final seen = <String>{};
  void add(CodexComposerMention mention) {
    final key = '${mention.kind.name}:${mention.insertText.toLowerCase()}';
    if (seen.add(key)) mentions.add(mention);
  }

  for (final bot in registry.bots) {
    final pluginId = bot.miniAppId;
    final slug = codexMentionSlug(pluginId);
    add(
      CodexComposerMention(
        id: 'bot:${bot.botId}',
        label: bot.title,
        description: bot.subtitle.trim().isEmpty
            ? '绑定 $pluginId 插件'
            : '${bot.subtitle} · $pluginId',
        insertText: '@$slug',
        pluginId: pluginId,
        kind: CodexComposerMentionKind.bot,
      ),
    );
  }

  for (final manifest in registry.miniApps) {
    final pluginId = manifest.miniAppId;
    final slug = codexMentionSlug(pluginId);
    add(
      CodexComposerMention(
        id: 'plugin:$pluginId',
        label: manifest.title,
        description: manifest.pluginPath.isEmpty
            ? pluginId
            : '$pluginId · ${manifest.pluginPath}',
        insertText: '@plugin:$slug',
        pluginId: pluginId,
        kind: CodexComposerMentionKind.plugin,
      ),
    );
    for (final skill in manifest.skills) {
      add(
        CodexComposerMention(
          id: 'skill:$pluginId:$skill',
          label: skill,
          description: '${manifest.title} · Skill',
          insertText: r'$' + skill,
          pluginId: pluginId,
          kind: CodexComposerMentionKind.skill,
        ),
      );
    }
    for (final server in manifest.mcpServers) {
      add(
        CodexComposerMention(
          id: 'mcp:$pluginId:$server',
          label: server,
          description: '${manifest.title} · MCP Server',
          insertText: '@mcp:${codexMentionSlug(server)}',
          pluginId: pluginId,
          kind: CodexComposerMentionKind.mcp,
        ),
      );
    }
  }
  return mentions;
}

String codexMentionSlug(String value) {
  final normalized = value
      .trim()
      .replaceFirst(RegExp(r'^official\.'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  return normalized.replaceAll(RegExp(r'^-+|-+$'), '');
}

List<CodexComposerMention> filterCodexComposerMentions(
  List<CodexComposerMention> mentions,
  String query, {
  int limit = 8,
}) {
  final needle = query.trim().toLowerCase();
  final filtered = mentions
      .where((mention) {
        if (needle.isEmpty) return true;
        return mention.label.toLowerCase().contains(needle) ||
            mention.description.toLowerCase().contains(needle) ||
            mention.insertText.toLowerCase().contains(needle) ||
            mention.kindLabel.toLowerCase().contains(needle);
      })
      .toList(growable: false);
  return filtered.take(limit).toList(growable: false);
}

class CodexDesktopModelOption {
  final String id;
  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;

  const CodexDesktopModelOption({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    this.icon = Icons.auto_awesome,
  });
}

class CodexDesktopChatInput extends StatefulWidget {
  static const defaultModelOptions = [
    CodexDesktopModelOption(
      id: 'deepseek-chat',
      label: 'DeepSeek Chat',
      shortLabel: 'Chat',
      subtitle: '通用对话、写作与工具调用',
      icon: Icons.bolt_outlined,
    ),
    CodexDesktopModelOption(
      id: 'deepseek-reasoner',
      label: 'DeepSeek Reasoner',
      shortLabel: 'Reasoner',
      subtitle: '推理、规划与复杂代码任务',
      icon: Icons.psychology_alt_outlined,
    ),
  ];

  final TextEditingController controller;
  final bool isBusy;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback? onTextChanged;
  final FutureOr<bool> Function(String action)? onAddActionSelected;
  final Widget? topContent;
  final String hintText;
  final List<CodexDesktopModelOption> modelOptions;
  final String selectedModelId;
  final ValueChanged<String>? onModelChanged;
  final LocalProject? selectedProject;
  final ValueChanged<LocalProject?>? onProjectChanged;
  final List<CodexComposerMention> mentions;
  final ValueChanged<CodexComposerMention>? onMentionSelected;

  const CodexDesktopChatInput({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.onSubmit,
    this.canSubmit = false,
    this.onTextChanged,
    this.onAddActionSelected,
    this.topContent,
    this.hintText = '随心输入',
    this.modelOptions = defaultModelOptions,
    this.selectedModelId = 'deepseek-chat',
    this.onModelChanged,
    this.selectedProject,
    this.onProjectChanged,
    this.mentions = const [],
    this.onMentionSelected,
  });

  @override
  State<CodexDesktopChatInput> createState() => _CodexDesktopChatInputState();
}

class _CodexDesktopChatInputState extends State<CodexDesktopChatInput> {
  static const _panelColor = Color(0xFF2C2C2E);
  static const _accentColor = Color(0xFFE56A54);

  bool _isFullAccess = true;
  List<LocalProject> _projects = const [];
  bool _isLoadingProjects = false;
  final FocusNode _inputFocus = FocusNode();
  int? _mentionStart;
  int? _mentionEnd;
  String _mentionQuery = '';
  int _selectedMentionIndex = 0;
  bool _mentionsDismissed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _inputFocus.addListener(_handleFocusChanged);
    unawaited(_loadProjects());
  }

  @override
  void didUpdateWidget(covariant CodexDesktopChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.mentions != widget.mentions) {
      _syncMentionQuery(notify: false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _inputFocus
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _mentionsDismissed = false;
    _syncMentionQuery();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _syncMentionQuery({bool notify = true}) {
    final selection = widget.controller.selection;
    int? start;
    int? end;
    var query = '';
    if (selection.isValid && selection.isCollapsed) {
      final cursor = selection.baseOffset;
      final text = widget.controller.text;
      if (cursor >= 0 && cursor <= text.length) {
        final beforeCursor = text.substring(0, cursor);
        final at = beforeCursor.lastIndexOf('@');
        if (at >= 0 &&
            (at == 0 || RegExp(r'\s').hasMatch(text[at - 1])) &&
            !RegExp(r'\s').hasMatch(beforeCursor.substring(at + 1))) {
          start = at;
          end = cursor;
          query = beforeCursor.substring(at + 1);
        }
      }
    }
    _mentionStart = start;
    _mentionEnd = end;
    _mentionQuery = query;
    final matches = _visibleMentions;
    if (_selectedMentionIndex >= matches.length) {
      _selectedMentionIndex = matches.isEmpty ? 0 : matches.length - 1;
    }
    if (notify && mounted) setState(() {});
  }

  List<CodexComposerMention> get _visibleMentions {
    if (_mentionsDismissed ||
        !_inputFocus.hasFocus ||
        _mentionStart == null ||
        widget.mentions.isEmpty) {
      return const [];
    }
    return filterCodexComposerMentions(widget.mentions, _mentionQuery);
  }

  void _insertMention(CodexComposerMention mention) {
    final start = _mentionStart;
    final end = _mentionEnd;
    if (start == null || end == null) return;
    final text = widget.controller.text;
    final insertion = '${mention.insertText} ';
    final nextText = text.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _mentionStart = null;
    _mentionEnd = null;
    _mentionQuery = '';
    _selectedMentionIndex = 0;
    widget.onMentionSelected?.call(mention);
    _inputFocus.requestFocus();
  }

  KeyEventResult _handleInputKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final mentions = _visibleMentions;
    if (mentions.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedMentionIndex = (_selectedMentionIndex + 1) % mentions.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedMentionIndex =
            (_selectedMentionIndex - 1 + mentions.length) % mentions.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _insertMention(mentions[_selectedMentionIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _mentionsDismissed = true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  CodexDesktopModelOption get _selectedModel {
    return widget.modelOptions.firstWhere(
      (model) => model.id == widget.selectedModelId,
      orElse: () => widget.modelOptions.first,
    );
  }

  bool get _canSubmit => !widget.isBusy && widget.canSubmit;

  @override
  Widget build(BuildContext context) {
    final selectedModel = _selectedModel;
    final projectLabel = widget.selectedProject?.name ?? '选择项目';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF38383A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.topContent != null) widget.topContent!,
              if (_visibleMentions.isNotEmpty) _buildMentionMenu(),
              Focus(
                onKeyEvent: _handleInputKey,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _inputFocus,
                  minLines: 2,
                  maxLines: 6,
                  enabled: !widget.isBusy,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.36,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      color: Color(0xFF747478),
                      fontSize: 16,
                    ),
                    contentPadding: EdgeInsets.fromLTRB(
                      16,
                      widget.topContent == null ? 16 : 10,
                      16,
                      8,
                    ),
                  ),
                  onChanged: (_) => widget.onTextChanged?.call(),
                  onSubmitted: (_) {
                    if (_visibleMentions.isEmpty && _canSubmit) {
                      widget.onSubmit();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Builder(
                      builder: (buttonContext) => _roundIconButton(
                        icon: Icons.add,
                        tooltip: '添加',
                        onTap: widget.isBusy
                            ? null
                            : () => _showAddMenu(buttonContext),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildAccessButton(),
                    const Spacer(),
                    Builder(
                      builder: (buttonContext) => _buildInlineModelButton(
                        selectedModel,
                        () => _showModelMenu(buttonContext),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.mic_none,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _canSubmit ? widget.onSubmit : null,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _canSubmit
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isBusy ? Icons.more_horiz : Icons.arrow_upward,
                          size: 20,
                          color: _canSubmit
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Builder(
                builder: (buttonContext) => _buildDropdownPill(
                  Icons.folder_outlined,
                  projectLabel,
                  active: widget.selectedProject != null,
                  onTap: () => _showProjectMenu(buttonContext),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (buttonContext) => _buildDropdownPill(
                  selectedModel.icon,
                  selectedModel.label,
                  active: true,
                  onTap: () => _showModelMenu(buttonContext),
                ),
              ),
              const SizedBox(width: 8),
              _buildDropdownPill(
                Icons.smart_toy_outlined,
                'codex/openclaw-remote...',
                active: false,
                onTap: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMentionMenu() {
    final mentions = _visibleMentions;
    return Container(
      constraints: const BoxConstraints(maxHeight: 330),
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF202022),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: mentions.length,
        itemBuilder: (context, index) {
          final mention = mentions[index];
          final selected = index == _selectedMentionIndex;
          return InkWell(
            onTap: () => _insertMention(mention),
            child: Container(
              color: selected
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(mention.icon, color: _accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                mention.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                mention.kindLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mention.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mention.insertText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: onTap == null ? 0.05 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: onTap == null ? 0.32 : 0.78),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildAccessButton() {
    return InkWell(
      onTap: () => setState(() => _isFullAccess = !_isFullAccess),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: _isFullAccess ? _accentColor : Colors.white54,
              size: 17,
            ),
            const SizedBox(width: 5),
            Text(
              _isFullAccess ? '完全访问' : '默认权限',
              style: TextStyle(
                color: _isFullAccess ? _accentColor : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: _isFullAccess ? _accentColor : Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineModelButton(
    CodexDesktopModelOption model,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              model.icon,
              color: Colors.white.withValues(alpha: 0.72),
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              model.shortLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withValues(alpha: 0.58),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownPill(
    IconData icon,
    String label, {
    required bool active,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.66), size: 15),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.46),
                size: 15,
              ),
            ],
          ],
        ),
      ),
    );
  }

  RelativeRect? _menuPosition(BuildContext anchorContext) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final anchor = anchorContext.findRenderObject() as RenderBox?;
    if (overlay == null || anchor == null) return null;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _showAddMenu(BuildContext anchorContext) async {
    final position = _menuPosition(anchorContext);
    if (position == null) return;
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: _panelColor,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 330, maxWidth: 390),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: Text(
            'Add',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        _menuItem(
          'files',
          Icons.attach_file,
          'Files and folders',
          '选择本机文件或图片作为素材',
        ),
        _menuItem('dharma', Icons.public, '全球法布施', '调用内置全球发送流程'),
        _menuItem('flashcards', Icons.style_outlined, '闪卡', '把链接、正文或素材制成背诵卡片'),
        _menuItem(
          'platform_publish',
          Icons.campaign_outlined,
          '法布施到平台',
          '生成发布草稿并推送到内容平台',
        ),
      ],
    );

    if (action == null) return;
    await widget.onAddActionSelected?.call(action);
  }

  Future<void> _showModelMenu(BuildContext anchorContext) async {
    final position = _menuPosition(anchorContext);
    if (position == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: _panelColor,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 310, maxWidth: 380),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: Text(
            '选择模型',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        ...widget.modelOptions.map(
          (model) => _menuItem(
            model.id,
            model.icon,
            model.label,
            model.subtitle,
            trailing: model.id == widget.selectedModelId ? Icons.check : null,
          ),
        ),
      ],
    );
    if (selected == null) return;
    widget.onModelChanged?.call(selected);
  }

  Future<void> _showProjectMenu(BuildContext anchorContext) async {
    final position = _menuPosition(anchorContext);
    if (position == null) return;
    await _loadProjects();
    if (!mounted) return;
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: _panelColor,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 430),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 44,
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white38, size: 18),
              const SizedBox(width: 9),
              Text(
                _isLoadingProjects ? '正在加载项目' : '搜索项目',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
        ..._projects
            .take(8)
            .map(
              (project) => _menuItem(
                'project:${project.path}',
                project.isExternal
                    ? Icons.folder_copy_outlined
                    : Icons.folder_outlined,
                project.name,
                project.path,
                trailing: widget.selectedProject?.path == project.path
                    ? Icons.check
                    : null,
              ),
            ),
        const PopupMenuDivider(),
        _menuItem(
          'add_project',
          Icons.create_new_folder_outlined,
          '添加新项目',
          '新建空白项目或选择本地文件夹',
          trailing: Icons.chevron_right,
        ),
        _menuItem(
          'none',
          Icons.folder_off_outlined,
          '不使用项目',
          '仅进行普通对话',
          trailing: widget.selectedProject == null ? Icons.check : null,
        ),
      ],
    );

    if (selected == null) return;
    if (selected == 'none') {
      widget.onProjectChanged?.call(null);
      return;
    }
    if (selected == 'add_project') {
      await _showAddProjectMenu(position);
      return;
    }
    if (selected.startsWith('project:')) {
      final path = selected.substring('project:'.length);
      final project = _projects.firstWhere(
        (item) => item.path == path,
        orElse: () =>
            LocalProject(name: path, path: path, updatedAt: DateTime.now()),
      );
      widget.onProjectChanged?.call(project);
    }
  }

  Future<void> _showAddProjectMenu(RelativeRect position) async {
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: _panelColor,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _menuItem('blank', Icons.add_box_outlined, '新建空白项目', '在应用工作区创建一个新文件夹'),
        _menuItem(
          'folder',
          Icons.folder_open_outlined,
          '使用现有文件夹',
          '选择本机文件夹作为项目',
        ),
      ],
    );

    if (action == 'blank') {
      await _createBlankProject();
    } else if (action == 'folder') {
      await _useExistingFolder();
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String title,
    String subtitle, {
    IconData? trailing,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 56,
      child: _DesktopInputMenuRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  Future<void> _loadProjects() async {
    if (_isLoadingProjects) return;
    setState(() => _isLoadingProjects = true);
    try {
      final projects = await ProjectService.instance.listProjects();
      if (mounted) setState(() => _projects = projects);
    } catch (_) {
      if (mounted) setState(() => _projects = const []);
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createBlankProject() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panelColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('新建空白项目', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '项目名称',
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    final project = await ProjectService.instance.createProject(name.trim());
    widget.onProjectChanged?.call(project);
    await _loadProjects();
  }

  Future<void> _useExistingFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择项目文件夹',
    );
    if (path == null || path.trim().isEmpty) return;
    final project = await ProjectService.instance.addProjectFromFolder(path);
    widget.onProjectChanged?.call(project);
    await _loadProjects();
  }
}

class _DesktopInputMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;

  const _DesktopInputMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.84), size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Icon(trailing, color: Colors.white.withValues(alpha: 0.55), size: 18),
        ],
      ],
    );
  }
}
