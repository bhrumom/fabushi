import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sutra_table_of_contents.dart';
import '../models/merit_benefit.dart';
import '../services/merit_benefit_service.dart';

/// 标签页类型
enum TocTabType { toc, meritBenefit, aiOutline }

/// 微信读书风格的目录底部弹出面板
///
/// 支持三个标签页：目录 | 功德利益 | AI大纲
class SutraTocBottomSheet extends StatefulWidget {
  /// 目录数据
  final SutraTableOfContents tableOfContents;

  /// 当前阅读的段落索引
  final int currentParagraphIndex;

  /// 章节点击回调
  final void Function(SutraChapter chapter) onChapterTap;

  /// 经文全文（用于功德利益分析）
  final String fullText;

  /// 功德利益句点击回调
  final void Function(int paragraphIndex)? onMeritSentenceTap;

  const SutraTocBottomSheet({
    required this.tableOfContents,
    required this.currentParagraphIndex,
    required this.onChapterTap,
    required this.fullText,
    this.onMeritSentenceTap,
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
    required String fullText,
    void Function(int paragraphIndex)? onMeritSentenceTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SutraTocBottomSheet(
        tableOfContents: tableOfContents,
        currentParagraphIndex: currentParagraphIndex,
        onChapterTap: onChapterTap,
        fullText: fullText,
        onMeritSentenceTap: onMeritSentenceTap,
      ),
    );
  }
}

class _SutraTocBottomSheetState extends State<SutraTocBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  late int _currentChapterIndex;

  // 标签页状态
  TocTabType _selectedTab = TocTabType.toc;

  // 功德利益数据
  MeritBenefitData? _meritData;
  bool _isMeritLoading = false;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.tableOfContents.getCurrentChapterIndex(
      widget.currentParagraphIndex,
    );

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
      final targetOffset = (_currentChapterIndex - 1) * 56.0;
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

  /// 切换标签页
  void _selectTab(TocTabType tab) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTab = tab;
    });

    // 懒加载功德利益数据
    if (tab == TocTabType.meritBenefit &&
        _meritData == null &&
        !_isMeritLoading) {
      _loadMeritBenefitData();
    }
  }

  /// 加载功德利益数据
  Future<void> _loadMeritBenefitData() async {
    setState(() {
      _isMeritLoading = true;
    });

    try {
      final service = MeritBenefitService.instance;
      final data = await service.extractFromText(
        widget.fullText,
        widget.tableOfContents,
      );

      if (mounted) {
        setState(() {
          _meritData = data;
          _isMeritLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载功德利益数据失败: $e');
      if (mounted) {
        setState(() {
          _meritData = MeritBenefitData.empty;
          _isMeritLoading = false;
        });
      }
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

          // 当前阅读位置（仅目录标签显示）
          if (_selectedTab == TocTabType.toc) _buildCurrentReadingIndicator(),

          // 内容区域
          Expanded(child: _buildContentForTab()),

          // 去底部按钮（仅目录标签且章节较多时显示）
          if (_selectedTab == TocTabType.toc &&
              widget.tableOfContents.chapters.length > 10)
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
          Text('搜本书', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const Spacer(),
          // 三个标签
          _buildTabItem('目录', TocTabType.toc),
          const SizedBox(width: 8),
          _buildTabItem('功德利益', TocTabType.meritBenefit),
          const SizedBox(width: 8),
          _buildTabItem('AI大纲', TocTabType.aiOutline),
        ],
      ),
    );
  }

  /// 构建单个标签项
  Widget _buildTabItem(String label, TocTabType type) {
    final isSelected = _selectedTab == type;

    return GestureDetector(
      onTap: () => _selectTab(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// 根据当前标签构建内容区域
  Widget _buildContentForTab() {
    switch (_selectedTab) {
      case TocTabType.toc:
        return widget.tableOfContents.chapters.isEmpty
            ? _buildEmptyState('暂无目录', '此经文未识别到章节结构')
            : _buildChapterList();
      case TocTabType.meritBenefit:
        return _buildMeritBenefitContent();
      case TocTabType.aiOutline:
        return _buildEmptyState('AI大纲', '功能开发中，敬请期待');
    }
  }

  Widget _buildCurrentReadingIndicator() {
    final currentChapter = widget.tableOfContents.getCurrentChapter(
      widget.currentParagraphIndex,
    );

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
          const Text(
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
            style: const TextStyle(color: Color(0xFF4A90D9), fontSize: 14),
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
            Expanded(
              child: Text(
                chapter.title,
                style: TextStyle(
                  color: isCurrent ? const Color(0xFF4A90D9) : Colors.white,
                  fontSize: chapter.isVolume ? 16 : 15,
                  fontWeight: chapter.isVolume
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${chapter.paragraphIndex + 1}',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建功德利益内容
  Widget _buildMeritBenefitContent() {
    if (_isMeritLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 16),
            Text(
              '正在分析经文功德利益...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_meritData == null || _meritData!.sentences.isEmpty) {
      return _buildEmptyState('暂无功德利益', '未识别到功德利益相关句子');
    }

    // 按章节分组显示
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _meritData!.byChapter.length,
      itemBuilder: (context, index) {
        final entry = _meritData!.byChapter.entries.elementAt(index);
        final chapter = entry.key;
        final sentences = entry.value;

        return _buildMeritChapterSection(chapter, sentences);
      },
    );
  }

  /// 构建功德利益章节分组
  Widget _buildMeritChapterSection(
    SutraChapter? chapter,
    List<MeritBenefitSentence> sentences,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 章节标题
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFD4AF37),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chapter?.title ?? '正文',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${sentences.length}句',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        // 句子列表
        ...sentences.map((sentence) => _buildMeritSentenceItem(sentence)),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 构建功德利益句子项
  Widget _buildMeritSentenceItem(MeritBenefitSentence sentence) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        widget.onMeritSentenceTap?.call(sentence.paragraphIndex);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功德图标
            Container(
              margin: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.stars,
                color: Color(0xFFD4AF37).withValues(alpha: 0.8),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            // 句子文本
            Expanded(
              child: Text(
                sentence.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 20),
            const SizedBox(width: 4),
            Text(
              '去底部',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
