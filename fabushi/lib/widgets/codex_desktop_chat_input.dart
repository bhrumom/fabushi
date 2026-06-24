import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';

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
  final List<CodexDesktopModelOption> modelOptions;
  final String selectedModelId;
  final ValueChanged<String>? onModelChanged;
  final LocalProject? selectedProject;
  final ValueChanged<LocalProject?>? onProjectChanged;

  const CodexDesktopChatInput({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.onSubmit,
    this.canSubmit = false,
    this.onTextChanged,
    this.onAddActionSelected,
    this.modelOptions = defaultModelOptions,
    this.selectedModelId = 'deepseek-chat',
    this.onModelChanged,
    this.selectedProject,
    this.onProjectChanged,
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadProjects());
  }

  @override
  void didUpdateWidget(covariant CodexDesktopChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
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
              TextField(
                controller: widget.controller,
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '随心输入',
                  hintStyle: TextStyle(color: Color(0xFF747478), fontSize: 16),
                  contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                ),
                onChanged: (_) => widget.onTextChanged?.call(),
                onSubmitted: (_) {
                  if (_canSubmit) widget.onSubmit();
                },
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
