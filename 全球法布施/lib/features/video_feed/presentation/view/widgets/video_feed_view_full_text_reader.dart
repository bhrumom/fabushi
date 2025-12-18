import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

// ============================================================================
// 第一性原理极致优化版本
// ============================================================================

/// 字符类型枚举
enum CharType { chinese, punctuation, space, other }

/// 预处理后的字符数据
class CharData {
  final String char;
  final String? pinyin;
  final CharType type;
  
  const CharData(this.char, this.pinyin, this.type);
}

/// 段落数据
class ParagraphData {
  final List<CharData> chars;
  final bool isCurrentParagraph;
  
  const ParagraphData(this.chars, this.isCurrentParagraph);
}

/// 预处理后的完整文本数据
class ProcessedTextData {
  final List<ParagraphData> paragraphs;
  
  const ProcessedTextData(this.paragraphs);
}

// ============================================================================
// Trie 树 - O(k) 词组匹配，k为最长词组长度
// ============================================================================

class _PhraseTrieNode {
  final Map<String, _PhraseTrieNode> children = {};
  List<String>? pinyinList; // 非空表示是词组结尾
}

class PhraseTrie {
  final _PhraseTrieNode _root = _PhraseTrieNode();
  
  // 单例模式，全局共享
  static PhraseTrie? _instance;
  static PhraseTrie get instance {
    _instance ??= PhraseTrie._build();
    return _instance!;
  }
  
  PhraseTrie._build() {
    // 构建 Trie 树
    for (final entry in BuddhistPinyinDictionary.phraseMap.entries) {
      _insert(entry.key, entry.value);
    }
  }
  
  void _insert(String phrase, List<String> pinyinList) {
    var node = _root;
    for (int i = 0; i < phrase.length; i++) {
      final char = phrase[i];
      node.children.putIfAbsent(char, () => _PhraseTrieNode());
      node = node.children[char]!;
    }
    node.pinyinList = pinyinList;
  }
  
  /// 从 text[startIndex] 开始匹配，返回最长匹配的词组和拼音
  /// 返回 null 表示无匹配
  ({String phrase, List<String> pinyin})? matchLongest(String text, int startIndex) {
    var node = _root;
    String? longestPhrase;
    List<String>? longestPinyin;
    
    for (int i = startIndex; i < text.length; i++) {
      final char = text[i];
      final child = node.children[char];
      if (child == null) break;
      
      node = child;
      if (node.pinyinList != null) {
        longestPhrase = text.substring(startIndex, i + 1);
        longestPinyin = node.pinyinList;
      }
    }
    
    if (longestPhrase != null && longestPinyin != null) {
      return (phrase: longestPhrase, pinyin: longestPinyin);
    }
    return null;
  }
}

// ============================================================================
// 佛教专用拼音词典（保持不变）
// ============================================================================

class BuddhistPinyinDictionary {
  /// 佛教专用词组拼音映射
  static const Map<String, List<String>> phraseMap = {
    // ===== 常见佛教专用词 =====
    '南无': ['nā', 'mó'],
    '南無': ['nā', 'mó'],
    '般若': ['bō', 'rě'],
    '伽蓝': ['qié', 'lán'],
    '伽藍': ['qié', 'lán'],
    '瑜伽': ['yú', 'qié'],
    '僧伽': ['sēng', 'qié'],
    '伽陀': ['qié', 'tuó'],
    '阿伽': ['ā', 'qié'],
    
    // ===== 佛菩萨名号 =====
    '阿弥陀': ['ē', 'mí', 'tuó'],
    '释迦': ['shì', 'jiā'],
    '释迦牟尼': ['shì', 'jiā', 'móu', 'ní'],
    '观世音': ['guān', 'shì', 'yīn'],
    '观音': ['guān', 'yīn'],
    '地藏': ['dì', 'zàng'],
    '文殊': ['wén', 'shū'],
    '普贤': ['pǔ', 'xián'],
    '摩诃': ['mó', 'hē'],
    '摩訶': ['mó', 'hē'],
    '迦叶': ['jiā', 'shè'],
    '迦葉': ['jiā', 'shè'],
    '阿难': ['ā', 'nán'],
    '阿難': ['ā', 'nán'],
    '须菩提': ['xū', 'pú', 'tí'],
    '須菩提': ['xū', 'pú', 'tí'],
    '舍利弗': ['shè', 'lì', 'fú'],
    '目犍连': ['mù', 'qián', 'lián'],
    '目犍連': ['mù', 'qián', 'lián'],
    '弥勒': ['mí', 'lè'],
    '彌勒': ['mí', 'lè'],
    '药师': ['yào', 'shī'],
    '藥師': ['yào', 'shī'],
    '香云盖菩萨摩诃萨': ['xiāng', 'yún', 'gài', 'pú', 'sà', 'mó', 'hē', 'sà'],
    '本师释迦牟尼佛': ['běn', 'shī', 'shì', 'jiā', 'móu', 'ní', 'fó'],
    
    // ===== 经典名称 =====
    '华严': ['huā', 'yán'],
    '華嚴': ['huā', 'yán'],
    '楞严': ['léng', 'yán'],
    '楞嚴': ['léng', 'yán'],
    '楞伽': ['léng', 'qié'],
    '楞枷': ['léng', 'qié'],
    '法华': ['fǎ', 'huā'],
    '法華': ['fǎ', 'huā'],
    '涅槃': ['niè', 'pán'],
    '金刚': ['jīn', 'gāng'],
    '金剛': ['jīn', 'gāng'],
    '心经': ['xīn', 'jīng'],
    '心經': ['xīn', 'jīng'],
    '阿含': ['ā', 'hán'],
    
    // ===== 佛教术语 =====
    '菩提': ['pú', 'tí'],
    '菩萨': ['pú', 'sà'],
    '菩薩': ['pú', 'sà'],
    '三昧': ['sān', 'mèi'],
    '禅定': ['chán', 'dìng'],
    '禪定': ['chán', 'dìng'],
    '幢幡': ['chuáng', 'fān'],
    '宝盖': ['bǎo', 'gài'],
    '寶蓋': ['bǎo', 'gài'],
    '舍利': ['shè', 'lì'],
    '舍利子': ['shè', 'lì', 'zǐ'],
    '阿耨多罗': ['ā', 'nòu', 'duō', 'luó'],
    '阿耨多羅': ['ā', 'nòu', 'duō', 'luó'],
    '三藐三菩提': ['sān', 'miǎo', 'sān', 'pú', 'tí'],
    '波罗蜜': ['bō', 'luó', 'mì'],
    '波羅蜜': ['bō', 'luó', 'mì'],
    '波罗蜜多': ['bō', 'luó', 'mì', 'duō'],
    '波羅蜜多': ['bō', 'luó', 'mì', 'duō'],
    '给孤独': ['jǐ', 'gū', 'dú'],
    '給孤獨': ['jǐ', 'gū', 'dú'],
    '祇园': ['qí', 'yuán'],
    '祇園': ['qí', 'yuán'],
    '祗园': ['zhī', 'yuán'],
    '阿兰若': ['ā', 'lán', 'ruò'],
    '阿蘭若': ['ā', 'lán', 'ruò'],
    '那由他': ['nà', 'yóu', 'tā'],
    '恒河沙': ['héng', 'hé', 'shā'],
    '恆河沙': ['héng', 'hé', 'shā'],
    '娑婆': ['suō', 'pó'],
    '娑婆世界': ['suō', 'pó', 'shì', 'jiè'],
    '须弥': ['xū', 'mí'],
    '須彌': ['xū', 'mí'],
    '须弥山': ['xū', 'mí', 'shān'],
    '須彌山': ['xū', 'mí', 'shān'],
    '忉利天': ['dāo', 'lì', 'tiān'],
    '兜率天': ['dōu', 'shuài', 'tiān'],
    
    // ===== 咒语常见字组 =====
    '唵嘛呢': ['ōng', 'ma', 'ní'],
    '嘛呢叭': ['ma', 'ní', 'bā'],
    '叭咪吽': ['bā', 'mī', 'hōng'],
    '唵啊吽': ['ōng', 'ā', 'hōng'],
    '萨嚩诃': ['sà', 'pó', 'hē'],
    '薩嚩訶': ['sà', 'pó', 'hē'],
    '娑婆诃': ['suō', 'pó', 'hē'],
    '娑婆訶': ['suō', 'pó', 'hē'],
    '室利': ['shì', 'lì'],
    '达摩': ['dá', 'mó'],
    '達摩': ['dá', 'mó'],
    '怛侄他': ['dá', 'zhí', 'tuō'],
    '揭谛': ['jiē', 'dì'],
    '揭諦': ['jiē', 'dì'],
    
    // ===== 诵经前仪式 =====
    '炉香乍爇': ['lú', 'xiāng', 'zhà', 'ruò'],
    '法界蒙薰': ['fǎ', 'jiè', 'méng', 'xūn'],
    '诸佛海会悉遥闻': ['zhū', 'fó', 'hǎi', 'huì', 'xī', 'yáo', 'wén'],
    '随处结祥云': ['suí', 'chù', 'jié', 'xiáng', 'yún'],
    '诚意方殷': ['chéng', 'yì', 'fāng', 'yīn'],
    '诸佛现全身': ['zhū', 'fó', 'xiàn', 'quán', 'shēn'],
    '修唎修唎': ['xiū', 'lì', 'xiū', 'lì'],
    '摩诃修唎': ['mó', 'hē', 'xiū', 'lì'],
    '修修唎': ['xiū', 'xiū', 'lì'],
    '萨婆诃': ['sà', 'pó', 'hē'],
    '婆嚩秫驮': ['pó', 'wā', 'shú', 'tuó'],
    '婆嚩达摩婆嚩': ['pó', 'wā', 'dá', 'mó', 'pó', 'wā'],
    '婆嚩秫度憾': ['pó', 'wā', 'shú', 'dù', 'hàn'],
    '三满哆': ['sān', 'mǎn', 'duō'],
    '母驮喃': ['mǔ', 'tuó', 'nán'],
    '唵度噜度噜': ['ōng', 'dù', 'lū', 'dù', 'lū'],
    '地尾': ['dì', 'wěi'],
    '誐誐曩': ['yé', 'yé', 'nǎng'],
    '三婆嚩': ['sān', 'pó', 'wā'],
    '嚩日啰斛': ['fá', 'zì', 'la', 'hòng'],
  };

  /// 单字特殊读音映射
  static const Map<String, String> singleCharOverride = {
    '南': 'nā',
    '无': 'mó',
    '無': 'mó',
    '般': 'bō',
    '若': 'rě',
    '伽': 'qié',
    '叶': 'shè',
    '葉': 'shè',
    '给': 'jǐ',
    '給': 'jǐ',
    '华': 'huā',
    '華': 'huā',
    '幢': 'chuáng',
    '那': 'nà',
    '他': 'tā',
    '藏': 'zàng',
    '咒': 'zhòu',
    '诃': 'hē',
    '訶': 'hē',
    '嚩': 'pó',
    '缚': 'fù',
    '唵': 'ōng',
    '吽': 'hōng',
    '啰': 'la',
    '囉': 'la',
    '哆': 'duō',
    '谛': 'dì',
    '諦': 'dì',
    '揭': 'jiē',
    '阇': 'shé',
    '闍': 'shé',
    '耨': 'nòu',
    '昧': 'mèi',
    '婆': 'pó',
    '爇': 'ruò',
    '薰': 'xūn',
    '殷': 'yīn',
    '唎': 'lì',
    '驮': 'tuó',
    '喃': 'nán',
    '噜': 'lū',
    '嗡': 'ōng',
    '曩': 'nǎng',
    '斛': 'hòng',
    '誐': 'yé',
  };
}

// ============================================================================
// 诵经前仪式内容数据（保持不变）
// ============================================================================

class SutraPreludeData {
  static const List<String> jingWen = [
    '1、未诵前，漱口，濯手。当净三业，若三业无亏，则百福俱集。三业者，身、口、意也。端身正坐，如对圣容，则身业净也。口无杂言，断诸嬉笑，则口业净也。意不散乱，屏息万缘，则意业净也。',
    '2、未诵前，已诵后，俱要对圣像前合掌三礼。如无佛像，对经、对空礼拜亦可。',
  ];

  static const Map<String, String> xiangZan = {
    'title': '香赞',
    'pinyin': 'xiāng zàn',
    'times': '一遍',
    'content': '炉香乍爇．法界蒙薰．诸佛海会悉遥闻．随处结祥云．诚意方殷．诸佛现全身。',
    'ending': '南無香云盖菩萨摩诃萨',
    'endingNote': '合掌三称',
  };

  static const Map<String, String> jingKouYeZhenYan = {
    'title': '净口业真言',
    'pinyin': 'jìng kǒu yè zhēn yán',
    'times': '三遍',
    'content': '唵．修唎修唎．摩诃修唎．修修唎．萨婆诃。',
  };

  static const Map<String, String> jingSanYeZhenYan = {
    'title': '净三业真言',
    'pinyin': 'jìng sān yè zhēn yán',
    'times': '三遍',
    'content': '唵．娑嚩．婆嚩秫驮．娑嚩达摩娑嚩．婆嚩秫度憾。',
  };

  static const Map<String, String> anTuDiZhenYan = {
    'title': '安土地真言',
    'pinyin': 'ān tǔ dì zhēn yán',
    'times': '三遍',
    'content': '南無三满哆．母驮喃．唵度噜度噜．地尾．娑婆诃。',
  };

  static const Map<String, String> puGongYangZhenYan = {
    'title': '普供养真言',
    'pinyin': 'pǔ gòng yǎng zhēn yán',
    'times': '三遍',
    'content': '唵．誐誐曩．三婆嚩．嚩日啰斛。',
  };

  static const Map<String, String> naMoBenShiFo = {
    'title': '南無本师释迦牟尼佛',
    'pinyin': 'ná mó běn shī shì jiā móu ní fó',
    'note': '合掌三称',
  };

  static const Map<String, String> kaiJingJi = {
    'title': '开经偈',
    'pinyin': 'kāi jīng jì',
    'times': '一遍',
    'line1': '无上甚深微妙法',
    'line1Pinyin': 'wú shàng shèn shēn wēi miào fǎ',
    'line2': '百千万劫难遭遇',
    'line2Pinyin': 'bǎi qiān wàn jié nán zāo yù',
    'line3': '我今见闻得受持',
    'line3Pinyin': 'wǒ jīn jiàn wén dé shòu chí',
    'line4': '愿解如来真实义',
    'line4Pinyin': 'yuàn jiě rú lái zhēn shí yì',
  };
}

// ============================================================================
// 文本预处理器 - 在 isolate 中运行
// ============================================================================

class TextPreprocessor {
  /// 在 isolate 中预处理文本（避免阻塞 UI 线程）
  static Future<ProcessedTextData> processAsync(String text, String? currentParagraph) async {
    return compute(_processText, _ProcessInput(text, currentParagraph));
  }
  
  /// isolate 入口函数
  static ProcessedTextData _processText(_ProcessInput input) {
    final paragraphs = input.text.split(RegExp(r'[\n]+'));
    final trie = PhraseTrie.instance;
    
    final processedParagraphs = <ParagraphData>[];
    
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;
      
      final isCurrentParagraph = input.currentParagraph != null && 
          paragraph.contains(input.currentParagraph!);
      
      final chars = _processParagraph(paragraph, trie);
      processedParagraphs.add(ParagraphData(chars, isCurrentParagraph));
    }
    
    return ProcessedTextData(processedParagraphs);
  }
  
  /// 处理单个段落
  static List<CharData> _processParagraph(String paragraph, PhraseTrie trie) {
    final chars = <CharData>[];
    int i = 0;
    
    while (i < paragraph.length) {
      final char = paragraph[i];
      
      // 使用 Trie 树匹配词组 O(k)
      final match = trie.matchLongest(paragraph, i);
      
      if (match != null) {
        for (int j = 0; j < match.phrase.length; j++) {
          chars.add(CharData(match.phrase[j], match.pinyin[j], CharType.chinese));
        }
        i += match.phrase.length;
      } else if (_isChinese(char)) {
        final pinyin = BuddhistPinyinDictionary.singleCharOverride[char] ??
            PinyinHelper.getPinyin(char, separator: '', format: PinyinFormat.WITH_TONE_MARK);
        chars.add(CharData(char, pinyin, CharType.chinese));
        i++;
      } else if (char == ' ' || char == '\t') {
        chars.add(CharData(char, null, CharType.space));
        i++;
      } else if (_isPunctuation(char)) {
        chars.add(CharData(char, null, CharType.punctuation));
        i++;
      } else {
        chars.add(CharData(char, null, CharType.other));
        i++;
      }
    }
    
    return chars;
  }
  
  static bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF);
  }
  
  static bool _isPunctuation(String char) {
    const punctuations = '，。！？、；：""''（）【】《》…—·．';
    return punctuations.contains(char);
  }
}

class _ProcessInput {
  final String text;
  final String? currentParagraph;
  
  const _ProcessInput(this.text, this.currentParagraph);
}

// ============================================================================
// 复用的静态 Widget 实例
// ============================================================================

class _CachedWidgets {
  static const spaceWidget = SizedBox(width: 8);
  
  static const pinyinStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF88C0D0),
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
  
  static const charStyle = TextStyle(
    fontSize: 28,
    color: Colors.white,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  
  static const punctuationStyle = TextStyle(
    fontSize: 28,
    color: Colors.white70,
    fontWeight: FontWeight.w400,
  );
  
  static const preludePinyinStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9370DB),
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
  
  static const preludeCharStyle = TextStyle(
    fontSize: 26,
    color: Color(0xFFB22222),
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

// ============================================================================
// 主组件 - StatefulWidget + 异步加载
// ============================================================================

class VideoFeedViewFullTextReader extends StatefulWidget {
  const VideoFeedViewFullTextReader({
    required this.bookTitle,
    required this.fullText,
    this.currentParagraph,
    super.key,
  });

  final String bookTitle;
  final String fullText;
  final String? currentParagraph;

  @override
  State<VideoFeedViewFullTextReader> createState() => _VideoFeedViewFullTextReaderState();
}

class _VideoFeedViewFullTextReaderState extends State<VideoFeedViewFullTextReader> {
  ProcessedTextData? _processedData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preprocessText();
  }

  Future<void> _preprocessText() async {
    // 异步预处理，不阻塞 UI
    final data = await TextPreprocessor.processAsync(
      widget.fullText,
      widget.currentParagraph,
    );
    
    if (mounted) {
      setState(() {
        _processedData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.bookTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () => _showPinyinInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      '正在准备经文...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // 固定头部：诵经前仪式
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSutraPrelude(),
                const SizedBox(height: 32),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.amber.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    '—— 经文正文 ——',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // 虚拟滚动：经文段落
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final paragraph = _processedData!.paragraphs[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildParagraphWidget(paragraph),
              );
            },
            childCount: _processedData!.paragraphs.length,
          ),
        ),
        // 底部留白
        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),
      ],
    );
  }

  Widget _buildParagraphWidget(ParagraphData paragraph) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paragraph.isCurrentParagraph
            ? Colors.amber.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: paragraph.isCurrentParagraph
            ? Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 24,
        children: paragraph.chars.map(_buildCharWidget).toList(),
      ),
    );
  }

  Widget _buildCharWidget(CharData data) {
    switch (data.type) {
      case CharType.chinese:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.pinyin ?? '', style: _CachedWidgets.pinyinStyle),
              const SizedBox(height: 2),
              Text(data.char, style: _CachedWidgets.charStyle),
            ],
          ),
        );
      case CharType.space:
        return _CachedWidgets.spaceWidget;
      case CharType.punctuation:
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(data.char, style: _CachedWidgets.punctuationStyle),
        );
      case CharType.other:
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            data.char,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }

  // ============================================================================
  // 诵经前仪式构建（同步，因为内容固定且较少）
  // ============================================================================

  Widget _buildSutraPrelude() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreludeSectionTitle('诵经警文', 'sòng jīng jǐng wén'),
        const SizedBox(height: 16),
        ...SutraPreludeData.jingWen.map(_buildJingWenParagraph),
        const SizedBox(height: 32),
        _buildPreludeSectionWithContent(
          SutraPreludeData.xiangZan['title']!,
          SutraPreludeData.xiangZan['pinyin']!,
          SutraPreludeData.xiangZan['times']!,
          SutraPreludeData.xiangZan['content']!,
          ending: SutraPreludeData.xiangZan['ending'],
          endingNote: SutraPreludeData.xiangZan['endingNote'],
        ),
        const SizedBox(height: 32),
        _buildPreludeSectionWithContent(
          SutraPreludeData.jingKouYeZhenYan['title']!,
          SutraPreludeData.jingKouYeZhenYan['pinyin']!,
          SutraPreludeData.jingKouYeZhenYan['times']!,
          SutraPreludeData.jingKouYeZhenYan['content']!,
        ),
        const SizedBox(height: 32),
        _buildPreludeSectionWithContent(
          SutraPreludeData.jingSanYeZhenYan['title']!,
          SutraPreludeData.jingSanYeZhenYan['pinyin']!,
          SutraPreludeData.jingSanYeZhenYan['times']!,
          SutraPreludeData.jingSanYeZhenYan['content']!,
        ),
        const SizedBox(height: 32),
        _buildPreludeSectionWithContent(
          SutraPreludeData.anTuDiZhenYan['title']!,
          SutraPreludeData.anTuDiZhenYan['pinyin']!,
          SutraPreludeData.anTuDiZhenYan['times']!,
          SutraPreludeData.anTuDiZhenYan['content']!,
        ),
        const SizedBox(height: 32),
        _buildPreludeSectionWithContent(
          SutraPreludeData.puGongYangZhenYan['title']!,
          SutraPreludeData.puGongYangZhenYan['pinyin']!,
          SutraPreludeData.puGongYangZhenYan['times']!,
          SutraPreludeData.puGongYangZhenYan['content']!,
        ),
        const SizedBox(height: 32),
        _buildNaMoSection(),
        const SizedBox(height: 32),
        _buildKaiJingJi(),
      ],
    );
  }

  Widget _buildJingWenParagraph(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF9370DB),
          height: 1.8,
        ),
      ),
    );
  }

  Widget _buildPreludeSectionTitle(String title, String pinyin) {
    return Center(
      child: Column(
        children: [
          Text(
            pinyin,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9370DB),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFFDC143C),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreludeSectionWithContent(
    String title,
    String titlePinyin,
    String times,
    String content, {
    String? ending,
    String? endingNote,
  }) {
    return Column(
      children: [
        _buildPreludeSectionTitle(title, titlePinyin),
        const SizedBox(height: 8),
        Text(
          '（$times）',
          style: const TextStyle(fontSize: 14, color: Color(0xFF9370DB)),
        ),
        const SizedBox(height: 16),
        _buildPreludeContentWithPinyin(content),
        if (ending != null) ...[
          const SizedBox(height: 20),
          _buildPreludeEndingWithPinyin(ending, endingNote),
        ],
      ],
    );
  }

  Widget _buildPreludeContentWithPinyin(String text) {
    final widgets = <Widget>[];
    final trie = PhraseTrie.instance;
    int i = 0;

    while (i < text.length) {
      final char = text[i];
      final match = trie.matchLongest(text, i);

      if (match != null) {
        for (int j = 0; j < match.phrase.length; j++) {
          widgets.add(_buildPreludeCharWithPinyin(match.phrase[j], match.pinyin[j]));
        }
        i += match.phrase.length;
      } else if (_isChinese(char)) {
        final pinyin = BuddhistPinyinDictionary.singleCharOverride[char] ??
            PinyinHelper.getPinyin(char, separator: '', format: PinyinFormat.WITH_TONE_MARK);
        widgets.add(_buildPreludeCharWithPinyin(char, pinyin));
        i++;
      } else if (char == '．' || char == '。' || char == '，' || _isPunctuation(char)) {
        widgets.add(_buildPreludePunctuation(char));
        i++;
      } else if (char == ' ' || char == '\t') {
        widgets.add(_CachedWidgets.spaceWidget);
        i++;
      } else {
        widgets.add(_buildPreludeNonChineseChar(char));
        i++;
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 28,
      children: widgets,
    );
  }

  Widget _buildPreludeCharWithPinyin(String char, String pinyin) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pinyin, style: _CachedWidgets.preludePinyinStyle),
          const SizedBox(height: 2),
          Text(char, style: _CachedWidgets.preludeCharStyle),
        ],
      ),
    );
  }

  Widget _buildPreludePunctuation(String char) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 26,
          color: Color(0xFFB22222),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildPreludeNonChineseChar(String char) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 22,
          color: Color(0xFFB22222),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPreludeEndingWithPinyin(String ending, String? note) {
    return Column(
      children: [
        _buildPreludeContentWithPinyin(ending),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            '（$note）',
            style: const TextStyle(fontSize: 14, color: Color(0xFFDC143C)),
          ),
        ],
      ],
    );
  }

  Widget _buildNaMoSection() {
    final data = SutraPreludeData.naMoBenShiFo;
    return Column(
      children: [
        Text(
          data['pinyin']!,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9370DB),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildPreludeContentWithPinyin(data['title']!),
        const SizedBox(height: 8),
        Text(
          '（${data['note']}）',
          style: const TextStyle(fontSize: 14, color: Color(0xFFDC143C)),
        ),
      ],
    );
  }

  Widget _buildKaiJingJi() {
    final data = SutraPreludeData.kaiJingJi;
    return Column(
      children: [
        _buildPreludeSectionTitle(data['title']!, data['pinyin']!),
        const SizedBox(height: 8),
        Text(
          '（${data['times']}）',
          style: const TextStyle(fontSize: 14, color: Color(0xFF9370DB)),
        ),
        const SizedBox(height: 20),
        _buildKaiJingLine(data['line1']!, data['line1Pinyin']!),
        const SizedBox(height: 16),
        _buildKaiJingLine(data['line2']!, data['line2Pinyin']!),
        const SizedBox(height: 16),
        _buildKaiJingLine(data['line3']!, data['line3Pinyin']!),
        const SizedBox(height: 16),
        _buildKaiJingLine(data['line4']!, data['line4Pinyin']!),
      ],
    );
  }

  Widget _buildKaiJingLine(String text, String pinyin) {
    return Column(
      children: [
        Text(
          pinyin,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9370DB),
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 24,
            color: Color(0xFFB22222),
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  void _showPinyinInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text('佛教专用拼音', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            '本阅读器使用佛教专用拼音词典，确保经文发音准确。\n\n'
            '常见特殊读音：\n'
            '• 南无 → nā mó（非 nán wú）\n'
            '• 般若 → bō rě（非 bān ruò）\n'
            '• 伽蓝 → qié lán（非 jiā lán）\n'
            '• 迦叶 → jiā shè（非 jiā yè）\n'
            '• 华严 → huā yán（非 huá yán）\n'
            '• 幢幡 → chuáng fān（非 zhuàng fān）\n'
            '• 三昧 → sān mèi\n'
            '• 菩萨 → pú sà\n\n'
            '这些读音源自梵文音译和古汉语传承。',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF);
  }

  bool _isPunctuation(String char) {
    const punctuations = '，。！？、；：""''（）【】《》…—·．';
    return punctuations.contains(char);
  }
}
