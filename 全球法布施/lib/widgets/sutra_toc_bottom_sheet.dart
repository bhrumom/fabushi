import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sutra_table_of_contents.dart';

/// 微信读书风格的目录底部弹出面板
class SutraTocBottomSheet extends StatefulWidget {
  /// 目录数据
  final SutraTableOfContents tableOfContents;
  
  /// 当前阅读的段落索引
  final int currentParagraphIndex;
  
  /// 章节点击回调
  final void Function(SutraChapter chapter) onChapterTap;

  const SutraTocBottomSheet({
    required this.tableOfContents,
    required this.currentParagraphIndex,
    required this.onChapterTap,
    super.key,
  });

  @override
  State<SutraTocBottomSheet> createState() => _SutraTocBottomSheetState();
  
  /// 显示目录面板
  static Future<void> show(
    BuildContext context, {
    required SutraTableOfContents tableOfContents,
    required int currentParagraphIndex,
    required void Function(SutraChapter chapter) onChapterTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SutraTocBottomSheet(
        tableOfContents: tableOfContents,
        currentParagraphIndex: currentParagraphIndex,
        onChapterTap: onChapterTap,
      ),
    );
  }
}

class _SutraTocBottomSheetState extends State<SutraTocBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  late int _currentChapterIndex;
  
  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.tableOfContents
        .getCurrentChapterIndex(widget.currentParagraphIndex);
    
    // 延迟滚动到当前章节
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToCurrentChapter() {
    if (_currentChapterIndex > 0 && _scrollController.hasClients) {
      final targetOffset = (_currentChapterIndex - 1) * 56.0; // 每个item约56高度
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 顶部标签栏
          _buildTabBar(),
          
          const Divider(height: 1, color: Color(0xFF333333)),
          
          // 当前阅读位置
          _buildCurrentReadingIndicator(),
          
          // 章节列表
          Expanded(
            child: widget.tableOfContents.chapters.isEmpty
                ? _buildEmptyState()
                : _buildChapterList(),
          ),
          
          // 去底部按钮
          if (widget.tableOfContents.chapters.length > 10)
            _buildGoToBottomButton(),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 搜索图标
          Icon(Icons.search, color: Colors.grey[400], size: 20),
          const SizedBox(width: 8),
          Text(
            '搜本书',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const Spacer(),
          // 目录标签（选中状态）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '目录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // AI大纲标签（未选中）
          Text(
            'AI大纲',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentReadingIndicator() {
    final currentChapter = widget.tableOfContents
        .getCurrentChapter(widget.currentParagraphIndex);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_outline,
            color: Color(0xFF4A90D9),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '当前读到',
            style: TextStyle(
              color: Color(0xFF4A90D9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            currentChapter?.title ?? '开始',
            style: const TextStyle(
              color: Color(0xFF4A90D9),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildChapterList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.tableOfContents.chapters.length,
      itemBuilder: (context, index) {
        final chapter = widget.tableOfContents.chapters[index];
        final isCurrent = index == _currentChapterIndex;
        
        return _buildChapterItem(chapter, index, isCurrent);
      },
    );
  }
  
  Widget _buildChapterItem(SutraChapter chapter, int index, bool isCurrent) {
    // 根据层级设置缩进
    final leftPadding = chapter.level == 0 ? 0.0 : 20.0;
    
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        widget.onChapterTap(chapter);
      },
      child: Container(
        padding: EdgeInsets.only(
          left: leftPadding,
          right: 8,
          top: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 章节标题
            Expanded(
              child: Text(
                chapter.title,
                style: TextStyle(
                  color: isCurrent ? const Color(0xFF4A90D9) : Colors.white,
                  fontSize: chapter.isVolume ? 16 : 15,
                  fontWeight: chapter.isVolume ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // 页码或进度指示
            Text(
              '${chapter.paragraphIndex + 1}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无目录',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '此经文未识别到章节结构',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoToBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _scrollToBottom();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              '去底部',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
