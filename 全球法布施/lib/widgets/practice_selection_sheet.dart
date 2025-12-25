import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/meditation_session_manager.dart';

/// 必选功课底部弹窗
/// 
/// 首次进入禅室时显示，要求用户选择一门修行功课
/// 数据源与首页素材选择表一致（使用 asset-manifest.json）
/// 支持搜索功能
class PracticeSelectionSheet extends StatefulWidget {
  final VoidCallback? onSelected;

  const PracticeSelectionSheet({
    super.key,
    this.onSelected,
  });

  @override
  State<PracticeSelectionSheet> createState() => _PracticeSelectionSheetState();
}

class _PracticeSelectionSheetState extends State<PracticeSelectionSheet> {
  final MeditationSessionManager _sessionManager = MeditationSessionManager();
  final TextEditingController _searchController = TextEditingController();
  
  // 所有文本素材（排除R2）
  List<Map<String, dynamic>> _allPractices = [];
  // 按目录分组
  Map<String, List<Map<String, dynamic>>> _groupedPractices = {};
  // 搜索结果
  List<Map<String, dynamic>> _searchResults = [];
  
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTitle;
  String? _selectedFilePath;
  
  // 搜索防抖
  Timer? _debounceTimer;
  // 展开状态
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadPractices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _performSearch(query);
        });
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchResults.clear();
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    _searchResults = _allPractices.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery);
    }).toList();
  }

  Future<void> _loadPractices() async {
    try {
      setState(() => _isLoading = true);

      // 加载 asset-manifest.json
      final String manifestString = await rootBundle.loadString('assets/data/asset-manifest.json');
      final List<dynamic> files = json.decode(manifestString);

      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> allPractices = [];

      for (var fileInfo in files) {
        final String key = fileInfo['key'] ?? '';
        final String source = fileInfo['source'] ?? '';
        
        // 排除 R2 素材、JSON 文件、隐藏文件
        if (source == 'r2' ||
            key.toLowerCase().endsWith('.json') ||
            key.contains('/.DS_Store') ||
            key.startsWith('.')) {
          continue;
        }
        
        // 只包含 txt 文件（经文素材）
        if (!key.toLowerCase().endsWith('.txt')) {
          continue;
        }

        if (key.contains('/')) {
          final parts = key.split('/');
          final fileName = parts.last.replaceAll('.txt', '');
          final directory = parts.sublist(0, parts.length - 1).join('/');

          final assetInfo = {
            'name': fileName,
            'key': key,
            'directory': directory,
            'source': source,
          };

          if (!groups.containsKey(directory)) {
            groups[directory] = [];
          }
          groups[directory]!.add(assetInfo);
          allPractices.add(assetInfo);
        }
      }

      // 排序
      final sortedGroups = Map<String, List<Map<String, dynamic>>>.fromEntries(
        groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );

      setState(() {
        _groupedPractices = sortedGroups;
        _allPractices = allPractices;
        _isLoading = false;
      });
      
      debugPrint('加载了 ${allPractices.length} 个经文素材，分为 ${sortedGroups.length} 个分组');
    } catch (e) {
      debugPrint('加载功课列表失败: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedTitle == null || _selectedFilePath == null) return;
    
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '确认选择功课',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您选择了：$_selectedTitle',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '一旦确认，功课将锁定，无法更改。\n请慎重选择！',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('确认锁定', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 锁定功课
      final success = await _sessionManager.selectAndLockPractice(
        _selectedTitle!,
        _selectedFilePath!,
      );
      
      if (success && mounted) {
        Navigator.pop(context);
        widget.onSelected?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选定功课：$_selectedTitle'),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 手柄
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题和关闭按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // 占位
                const Text(
                  '🙏 选择修行功课',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // 重要警告提醒
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.2),
                  Colors.orange.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '重要提醒',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '一旦确认选择，功课将永久锁定，无法修改！',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Text(
            '请选择一门深入修行的功课',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          
          // 搜索栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索经文标题...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),
          
          // 功课列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  )
                : _searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildGroupedList(),
          ),
          
          // 底部确认按钮
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedTitle != null ? _confirmSelection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _selectedTitle != null ? '确认选择「$_selectedTitle」' : '请先选择一门功课',
                    style: TextStyle(
                      color: _selectedTitle != null ? Colors.black : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              '未找到 "$_searchQuery" 相关的经文',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final practice = _searchResults[index];
        return _buildPracticeItem(practice);
      },
    );
  }

  Widget _buildGroupedList() {
    if (_groupedPractices.isEmpty) {
      return const Center(
        child: Text('暂无经文素材', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _groupedPractices.length,
      itemBuilder: (context, index) {
        final entry = _groupedPractices.entries.elementAt(index);
        final directory = entry.key;
        final practices = entry.value;
        final isExpanded = _expandedGroups.contains(directory);
        final dirName = directory.split('/').last;

        return Column(
          children: [
            // 分组标题
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: const Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
              title: Text(
                dirName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${practices.length} 个经文',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white54,
              ),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(directory);
                  } else {
                    _expandedGroups.add(directory);
                  }
                });
              },
            ),
            // 展开的内容
            if (isExpanded)
              ...practices.map((p) => _buildPracticeItem(p)),
          ],
        );
      },
    );
  }

  Widget _buildPracticeItem(Map<String, dynamic> practice) {
    final title = practice['name'] ?? '未知';
    final filePath = practice['key'] ?? '';
    final isSelected = _selectedTitle == title && _selectedFilePath == filePath;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4AF37).withOpacity(0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: const Color(0xFFD4AF37), width: 2)
              : null,
        ),
        child: Icon(
          Icons.auto_stories,
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 26)
          : const Icon(Icons.circle_outlined, color: Colors.white24, size: 26),
      onTap: () {
        setState(() {
          _selectedTitle = title;
          _selectedFilePath = filePath;
        });
      },
    );
  }
}

/// 显示功课选择弹窗（可关闭）
Future<void> showPracticeSelectionSheet(BuildContext context, {VoidCallback? onSelected}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PracticeSelectionSheet(onSelected: onSelected),
  );
}
