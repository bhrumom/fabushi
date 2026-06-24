import 'package:flutter/material.dart';
import '../../services/local_ai_conversation_store.dart';
import '../../services/project_service.dart';

class CodexSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CodexSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<CodexSidebar> createState() => _CodexSidebarState();
}

class _CodexSidebarState extends State<CodexSidebar> {
  bool _isCollapsed = false;
  List<LocalProject> _projects = [];
  List<LocalAiConversationRecord> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final projects = await ProjectService.instance.listProjects();
    final chats = await LocalAiConversationStore.instance.list();
    if (mounted) {
      setState(() {
        _projects = projects;
        _chats = chats;
      });
    }
  }

  Future<void> _createNewProject() async {
    final TextEditingController controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新项目', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2E),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '输入项目名称...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ProjectService.instance.createProject(name.trim());
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isCollapsed ? 70 : 260,
      color: const Color(0xFF18181A), // Dark background matching Codex
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40), // Top padding for window controls (macOS)
          
          // Top Actions
          _buildSidebarItem(
            icon: Icons.chat_bubble_outline,
            label: '新对话',
            isSelected: widget.selectedIndex == 0,
            onTap: () => widget.onDestinationSelected(0),
          ),
          _buildSidebarItem(
            icon: Icons.search,
            label: '搜索',
            isSelected: false,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.public,
            label: '全球法布施',
            isSelected: widget.selectedIndex == 1,
            onTap: () => widget.onDestinationSelected(1),
          ),
          _buildSidebarItem(
            icon: Icons.self_improvement,
            label: '禅室',
            isSelected: widget.selectedIndex == 2,
            onTap: () => widget.onDestinationSelected(2),
          ),
          _buildSidebarItem(
            icon: Icons.extension_outlined,
            label: '插件',
            isSelected: false,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.auto_awesome_outlined,
            label: '自动化',
            isSelected: false,
            onTap: () {},
          ),
          
          const SizedBox(height: 12),
          
          // Collapse Toggle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 10 : 16.0),
            child: InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isCollapsed)
                      Text(
                        '全部收起',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    Icon(
                      _isCollapsed ? Icons.keyboard_tab : Icons.menu_open,
                      size: 16,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),

          // Projects Section
          if (!_isCollapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '项目',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: _createNewProject,
                    child: Icon(Icons.add, size: 16, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final proj = _projects[index];
                  return _buildProjectItem(proj.name);
                },
              ),
            ),

            // Chats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '对话',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return _buildChatItem(chat);
                },
              ),
            ),
          ] else ...[
             const Spacer(),
          ],
          
          // Bottom Actions
          _buildSidebarItem(
            icon: Icons.person_outline,
            label: '个人资料',
            isSelected: widget.selectedIndex == 3,
            onTap: () => widget.onDestinationSelected(3),
          ),
          _buildSidebarItem(
            icon: Icons.settings_outlined,
            label: '设置',
            isSelected: widget.selectedIndex == 4,
            onTap: () => widget.onDestinationSelected(4),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProjectItem(String name) {
    return InkWell(
      onTap: () {
        // Handle project selection
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(LocalAiConversationRecord chat) {
    return InkWell(
      onTap: () {
        // Open this chat
        // We will pass this ID to the main screen later
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          chat.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected && !_isCollapsed ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
