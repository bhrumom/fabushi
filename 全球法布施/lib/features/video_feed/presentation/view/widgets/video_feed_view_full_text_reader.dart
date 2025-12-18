import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

/// 佛教专用拼音词典
/// 
/// 佛经中许多字的读音与现代汉语不同，这是因为：
/// 1. 梵文音译的保留 - 保留原始发音的神圣性
/// 2. 古汉语发音的传承 - 中古汉语发音特点
/// 3. 宗教术语的特殊性 - 密宗对发音准确性的要求
class BuddhistPinyinDictionary {
  /// 佛教专用词组拼音映射
  /// 格式：'词组': ['拼音1', '拼音2', ...]
  static const Map<String, List<String>> phraseMap = {
    // ===== 常见佛教专用词 =====
    '南无': ['nā', 'mó'],
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
  };

  /// 单字特殊读音映射（在特定佛教语境中）
  /// 这些字在佛经中有特殊读音
  static const Map<String, String> singleCharOverride = {
    '南': 'nā',      // "南无"中读 nā
    '无': 'mó',      // "南无"中读 mó (无 → 摩)
    '無': 'mó',      // 繁体
    '般': 'bō',      // "般若"中读 bō
    '若': 'rě',      // "般若"中读 rě
    '伽': 'qié',     // 佛经中多读 qié
    '叶': 'shè',     // "迦叶"中读 shè
    '葉': 'shè',     // 繁体
    '给': 'jǐ',      // "给孤独"中读 jǐ
    '給': 'jǐ',      // 繁体
    '华': 'huā',     // "华严"中读 huā
    '華': 'huā',     // 繁体
    '幢': 'chuáng',  // "幢幡"中读 chuáng
    '那': 'nà',      // 佛经中常读 nà
    '他': 'tā',      // "那由他"中读 tā
    '藏': 'zàng',    // "地藏"中读 zàng
    '咒': 'zhòu',    // 咒语
    '诃': 'hē',      // 梵音 ha
    '訶': 'hē',      // 繁体
    '嚩': 'pó',      // 梵音 va/wa → pó
    '缚': 'fù',      // 有时读 wā
    '唵': 'ōng',     // 梵音 om
    '吽': 'hōng',    // 梵音 hum
    '啰': 'la',      // 梵音 la
    '囉': 'la',      // 繁体
    '哆': 'duō',     // 梵音
    '谛': 'dì',      // "揭谛"中读 dì
    '諦': 'dì',      // 繁体
    '揭': 'jiē',     // "揭谛"中读 jiē
    '阇': 'shé',     // 梵音
    '闍': 'shé',     // 繁体
    '耨': 'nòu',     // "阿耨多罗"中读 nòu
    '昧': 'mèi',     // "三昧"中读 mèi
    '婆': 'pó',      // 常见梵音
  };
}

/// 全文阅读器 - 显示带拼音标注的文字内容
/// 
/// 特点：
/// - 使用佛教专用拼音词典确保发音准确
/// - 支持词组优先匹配（如"南无"整体识别）
/// - 每个汉字头上显示拼音，类似注音阅读模式
class VideoFeedViewFullTextReader extends StatelessWidget {
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
          bookTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // 添加一个提示按钮，说明使用佛教专用拼音
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () => _showPinyinInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildPinyinText(fullText),
        ),
      ),
    );
  }

  /// 显示拼音说明对话框
  void _showPinyinInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text(
          '佛教专用拼音',
          style: TextStyle(color: Colors.white),
        ),
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

  /// 构建带拼音的文本内容
  Widget _buildPinyinText(String text) {
    // 将文本按段落分割
    final paragraphs = text.split(RegExp(r'[\n]+'));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) {
          return const SizedBox(height: 16);
        }
        
        final isCurrentParagraph = currentParagraph != null && 
            paragraph.contains(currentParagraph!);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrentParagraph 
                ? Colors.amber.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isCurrentParagraph
                ? Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: _buildParagraphWithPinyin(paragraph),
        );
      }).toList(),
    );
  }

  /// 构建单个段落的拼音文本（支持词组优先匹配）
  Widget _buildParagraphWithPinyin(String paragraph) {
    final List<Widget> charWidgets = [];
    int i = 0;
    
    while (i < paragraph.length) {
      final char = paragraph[i];
      
      // 尝试匹配佛教专用词组（最长匹配优先）
      final matchResult = _matchBuddhistPhrase(paragraph, i);
      
      if (matchResult != null) {
        // 找到佛教专用词组
        final phrase = matchResult['phrase'] as String;
        final pinyinList = matchResult['pinyin'] as List<String>;
        
        for (int j = 0; j < phrase.length; j++) {
          charWidgets.add(_buildCharWithPinyin(phrase[j], pinyinList[j]));
        }
        i += phrase.length;
      } else if (_isChinese(char)) {
        // 单个汉字 - 优先使用佛教单字覆盖
        String pinyin = BuddhistPinyinDictionary.singleCharOverride[char] ??
            PinyinHelper.getPinyin(char, separator: '', format: PinyinFormat.WITH_TONE_MARK);
        
        charWidgets.add(_buildCharWithPinyin(char, pinyin));
        i++;
      } else if (char == ' ' || char == '\t') {
        // 空格
        charWidgets.add(const SizedBox(width: 8));
        i++;
      } else if (_isPunctuation(char)) {
        // 标点符号 - 不显示拼音
        charWidgets.add(_buildPunctuation(char));
        i++;
      } else {
        // 其他字符（数字、英文等）
        charWidgets.add(_buildNonChineseChar(char));
        i++;
      }
    }
    
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 24, // 行间距要足够放下拼音
      children: charWidgets,
    );
  }

  /// 尝试匹配佛教专用词组（最长匹配优先）
  Map<String, dynamic>? _matchBuddhistPhrase(String text, int startIndex) {
    // 按词组长度从长到短尝试匹配
    final sortedPhrases = BuddhistPinyinDictionary.phraseMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final phrase in sortedPhrases) {
      if (startIndex + phrase.length <= text.length) {
        final substring = text.substring(startIndex, startIndex + phrase.length);
        if (substring == phrase) {
          return {
            'phrase': phrase,
            'pinyin': BuddhistPinyinDictionary.phraseMap[phrase]!,
          };
        }
      }
    }
    
    return null;
  }

  /// 构建带拼音的单个汉字 (Ruby Text 风格)
  Widget _buildCharWithPinyin(String char, String pinyin) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拼音 - 在上方
          Text(
            pinyin,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF88C0D0), // 清新的蓝色
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          // 汉字 - 在下方
          Text(
            char,
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标点符号（不带拼音）
  Widget _buildPunctuation(String char) {
    return Padding(
      padding: const EdgeInsets.only(top: 20), // 与拼音高度对齐
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white70,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// 构建非中文字符（不带拼音）
  Widget _buildNonChineseChar(String char) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 检查是否是中文字符
  bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    // 常用中文字符范围
    return (code >= 0x4E00 && code <= 0x9FFF) ||  // CJK Unified Ideographs
           (code >= 0x3400 && code <= 0x4DBF);    // CJK Extension A
  }

  /// 检查是否是标点符号
  bool _isPunctuation(String char) {
    const punctuations = '，。！？、；：""''（）【】《》…—·';
    return punctuations.contains(char);
  }
}
