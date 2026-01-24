import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../../models/sutra_table_of_contents.dart';
import '../../../../../models/merit_benefit.dart';
import '../../../../../services/merit_benefit_llm_service.dart';
import '../../../../../widgets/sutra_toc_bottom_sheet.dart';

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
// 诵经结束仪式内容数据（回向）
// ============================================================================

class SutraEpilogueData {
  /// 补阙真言
  static const Map<String, String> buQueZhenYan = {
    'title': '补阙真言',
    'pinyin': 'bǔ quē zhēn yán',
    'times': '三遍',
    'content': '南無喝啰怛那．哆啰夜耶．佉啰佉啰．俱住俱住．摩啰摩啰．虎啰．吽．贺贺．苏怛拏．吽．泼抹拏．娑婆诃。',
  };

  /// 补阙圆满真言
  static const Map<String, String> buQueYuanManZhenYan = {
    'title': '补阙圆满真言',
    'pinyin': 'bǔ quē yuán mǎn zhēn yán',
    'times': '三遍',
    'content': '唵．呼嚧呼嚧．社曳穆契．莎诃。',
  };

  /// 普回向真言
  static const Map<String, String> puHuiXiangZhenYan = {
    'title': '普回向真言',
    'pinyin': 'pǔ huí xiàng zhēn yán',
    'times': '三遍',
    'content': '唵．娑摩啰．娑摩啰．弥摩曩．萨哈啰．摩诃咱哈啰吽。',
  };

  /// 回向偈
  static const Map<String, String> huiXiangJi = {
    'title': '回向偈',
    'pinyin': 'huí xiàng jì',
    'times': '一遍',
    'line1': '愿以此功德',
    'line1Pinyin': 'yuàn yǐ cǐ gōng dé',
    'line2': '庄严佛净土',
    'line2Pinyin': 'zhuāng yán fó jìng tǔ',
    'line3': '上报四重恩',
    'line3Pinyin': 'shàng bào sì chóng ēn',
    'line4': '下济三途苦',
    'line4Pinyin': 'xià jì sān tú kǔ',
    'line5': '若有见闻者',
    'line5Pinyin': 'ruò yǒu jiàn wén zhě',
    'line6': '悉发菩提心',
    'line6Pinyin': 'xī fā pú tí xīn',
    'line7': '尽此一报身',
    'line7Pinyin': 'jìn cǐ yī bào shēn',
    'line8': '同生极乐国',
    'line8Pinyin': 'tóng shēng jí lè guó',
  };

  /// 三皈依
  static const Map<String, String> sanGuiYi = {
    'title': '三皈依',
    'pinyin': 'sān guī yī',
    'times': '一遍',
    'content1': '自皈依佛．当愿众生．体解大道．发无上心。',
    'content1Pinyin': 'zì guī yī fó．dāng yuàn zhòng shēng．tǐ jiě dà dào．fā wú shàng xīn。',
    'content2': '自皈依法．当愿众生．深入经藏．智慧如海。',
    'content2Pinyin': 'zì guī yī fǎ．dāng yuàn zhòng shēng．shēn rù jīng zàng．zhì huì rú hǎi。',
    'content3': '自皈依僧．当愿众生．统理大众．一切无碍．和南圣众。',
    'content3Pinyin': 'zì guī yī sēng．dāng yuàn zhòng shēng．tǒng lǐ dà zhòng．yī qiè wú ài．hé nán shèng zhòng。',
  };

  /// 结束说明
  static const String endingNote = '（发愿文。回向偈。当对佛跪念。念毕。起身三礼而退。）';
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

class _VideoFeedViewFullTextReaderState extends State<VideoFeedViewFullTextReader> 
    with SingleTickerProviderStateMixin {
  ProcessedTextData? _processedData;
  bool _isLoading = true;
  
  // 可折叠区块状态（默认收起）
  bool _isPreludeExpanded = false;
  bool _isEpilogueExpanded = false;
  
  // 延迟缓存的仪式内容（避免重复构建）
  Widget? _cachedPreludeContent;
  Widget? _cachedEpilogueContent;
  
  // 目录相关状态
  SutraTableOfContents? _tableOfContents;
  int _currentParagraphIndex = 0;
  
  // ScrollablePositionedList 控制器
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  /// 获取缓存的诵经前仪式内容
  Widget get _preludeContent => _cachedPreludeContent ??= RepaintBoundary(
    child: _buildSutraPrelude(),
  );
  
  /// 获取缓存的结束仪式内容
  Widget get _epilogueContent => _cachedEpilogueContent ??= RepaintBoundary(
    child: _buildSutraEpilogue(),
  );
  
  // ========= 功德利益 LLM 识别与高亮 =========
  final MeritBenefitLLMService _meritLLMService = MeritBenefitLLMService.instance;
  // 每个段落的功德利益句高亮范围
  final Map<int, List<MeritBenefitSentence>> _meritHighlights = {};
  // 正在识别的段落索引
  final Set<int> _recognizingParagraphs = {};
  // 原始段落文本（用于 LLM 识别）
  List<String> _rawParagraphs = [];

  @override
  void initState() {
    super.initState();
    _preprocessText();
    // 监听滚动位置变化
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }
  
  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }
  
  /// 根据可见项目更新当前段落索引
  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    
    // 找到第一个完全可见或部分可见的段落项
    // 跳过 index=0（诵经前仪式）
    final visibleParagraphs = positions
        .where((pos) => pos.index > 0 && pos.index <= (_processedData?.paragraphs.length ?? 0))
        .toList();
    
    if (visibleParagraphs.isEmpty) return;
    
    // 取最靠近顶部的可见段落
    visibleParagraphs.sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    final topVisible = visibleParagraphs.first;
    
    // index - 1 是因为 index=0 是诵经前仪式
    final newIndex = topVisible.index - 1;
    
    if (newIndex != _currentParagraphIndex && newIndex >= 0) {
      setState(() {
        _currentParagraphIndex = newIndex;
      });
    }
    
    // 触发可见段落的功德利益识别（懒加载）
    for (final pos in visibleParagraphs) {
      final paragraphIndex = pos.index - 1;
      if (paragraphIndex >= 0) {
        _recognizeParagraphMerit(paragraphIndex);
      }
    }
  }
  
  /// 识别单个段落的功德利益句（懒加载）
  Future<void> _recognizeParagraphMerit(int paragraphIndex) async {
    // 已识别或正在识别则跳过
    if (_meritHighlights.containsKey(paragraphIndex)) return;
    if (_recognizingParagraphs.contains(paragraphIndex)) return;
    if (paragraphIndex >= _rawParagraphs.length) return;
    
    // 检查模型状态
    if (!_meritLLMService.isModelReady) return;
    
    _recognizingParagraphs.add(paragraphIndex);
    
    try {
      final paragraph = _rawParagraphs[paragraphIndex];
      final sentences = await _meritLLMService.recognizeParagraph(paragraph, paragraphIndex);
      
      if (mounted) {
        setState(() {
          _meritHighlights[paragraphIndex] = sentences;
        });
        
        if (sentences.isNotEmpty) {
          debugPrint('📿 Reader: 段落 $paragraphIndex 识别到 ${sentences.length} 个功德利益句');
        }
      }
    } catch (e) {
      debugPrint('📿 Reader: 段落 $paragraphIndex 识别失败: $e');
    } finally {
      _recognizingParagraphs.remove(paragraphIndex);
    }
  }

  Future<void> _preprocessText() async {
    // 异步解析目录
    final toc = SutraTableOfContents.parse(widget.fullText, widget.bookTitle);
    
    // 保存原始段落文本（用于 LLM 识别）
    _rawParagraphs = widget.fullText.split(RegExp(r'[\n]+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    
    // 异步预处理，不阻塞 UI
    final data = await TextPreprocessor.processAsync(
      widget.fullText,
      widget.currentParagraph,
    );
    
    if (mounted) {
      setState(() {
        _processedData = data;
        _tableOfContents = toc;
        _isLoading = false;
      });
      
      // 首屏可见段落预加载功德利益识别
      _prefetchVisibleMerit();
    }
  }
  
  /// 预加载首屏可见段落的功德利益识别
  void _prefetchVisibleMerit() {
    if (_rawParagraphs.isEmpty) return;
    
    // 预加载前3个段落
    for (int i = 0; i < 3 && i < _rawParagraphs.length; i++) {
      _recognizeParagraphMerit(i);
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
            : Column(
                children: [
                  Expanded(child: _buildContent()),
                  _buildBottomToolbar(),
                ],
              ),
      ),
    );
  }


  /// 构建底部工具栏（微信读书风格）
  Widget _buildBottomToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 目录按钮
          _buildToolbarButton(
            icon: Icons.menu,
            label: '目录',
            onTap: _showTableOfContents,
          ),
          // 书签按钮
          _buildToolbarButton(
            icon: Icons.bookmark_border,
            label: '书签',
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('书签功能即将上线')),
              );
            },
          ),
          // 进度按钮
          _buildToolbarButton(
            icon: Icons.linear_scale,
            label: '进度',
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('进度功能即将上线')),
              );
            },
          ),
          // 亮度按钮
          _buildToolbarButton(
            icon: Icons.brightness_6,
            label: '亮度',
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('亮度设置即将上线')),
              );
            },
          ),
          // 字体按钮
          _buildToolbarButton(
            icon: Icons.text_fields,
            label: '字体',
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('字体设置即将上线')),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 显示目录面板
  void _showTableOfContents() {
    HapticFeedback.lightImpact();
    
    if (_tableOfContents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目录加载中...')),
      );
      return;
    }
    
    SutraTocBottomSheet.show(
      context,
      tableOfContents: _tableOfContents!,
      currentParagraphIndex: _currentParagraphIndex,
      onChapterTap: _scrollToChapter,
      fullText: widget.fullText,
      onMeritSentenceTap: _scrollToParagraph,
    );
  }
  
  /// 滚动到指定段落（用于功德利益句点击跳转）
  void _scrollToParagraph(int paragraphIndex) {
    if (paragraphIndex >= (_processedData?.paragraphs.length ?? 0)) return;
    
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: paragraphIndex + 1,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    
    setState(() {
      _currentParagraphIndex = paragraphIndex;
    });
  }

  
  /// 滚动到指定章节（精确跳转）
  void _scrollToChapter(SutraChapter chapter) {
    HapticFeedback.lightImpact();
    final paragraphIndex = chapter.paragraphIndex;
    if (paragraphIndex >= (_processedData?.paragraphs.length ?? 0)) return;
    
    // 精确跳转：index + 1 是因为列表中 index=0 是诵经前仪式
    // 经文段落从 index=1 开始
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: paragraphIndex + 1,
        alignment: 0.0, // 对齐到顶部
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    
    setState(() {
      _currentParagraphIndex = paragraphIndex;
    });
  }

  Widget _buildContent() {
    // 列表总项数 = 1（诵经前仪式） + 经文段落数 + 1（诵经结束仪式）
    final paragraphCount = _processedData!.paragraphs.length;
    final totalItems = 1 + paragraphCount + 1;
    
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // index 0: 诵经前仪式
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCollapsibleSection(
                  title: '诵经前仪式',
                  subtitle: '香赞・真言・开经偈',
                  isExpanded: _isPreludeExpanded,
                  onToggle: () => setState(() => _isPreludeExpanded = !_isPreludeExpanded),
                  content: _preludeContent,
                ),
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
          );
        }
        
        // index 1 ~ paragraphCount: 经文段落
        if (index <= paragraphCount) {
          final paragraphIndex = index - 1;
          final paragraph = _processedData!.paragraphs[paragraphIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildParagraphWidget(paragraph, paragraphIndex),
          );
        }
        
        // 最后一项: 诵经结束仪式
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
              _buildCollapsibleSection(
                title: '诵经结束仪式',
                subtitle: '补阙真言・回向偈・三皓依',
                isExpanded: _isEpilogueExpanded,
                onToggle: () => setState(() => _isEpilogueExpanded = !_isEpilogueExpanded),
                content: _epilogueContent,
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// 构建可折叠区块（极致优化版）
  /// 
  /// 优化点：
  /// - AnimatedSize: 仅展开时构建内容，收起时不占用内存
  /// - HapticFeedback: 点击时提供触觉反馈
  /// - Curves.easeOutCubic: 更自然的动画曲线
  /// - ClipRect: 防止动画过程中内容溢出
  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Column(
      children: [
        // 可点击的折叠标题栏
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact(); // 触觉反馈
            onToggle();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isExpanded 
                  ? Colors.white.withValues(alpha: 0.12) 
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpanded 
                    ? Colors.amber.withValues(alpha: 0.5) 
                    : Colors.amber.withValues(alpha: 0.3),
                width: isExpanded ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // 展开/收起图标（旋转动画）
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.chevron_right,
                    color: isExpanded ? Colors.amber : Colors.amber.withValues(alpha: 0.8),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFFDC143C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // 展开/收起提示文字（带动画）
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isExpanded ? '收起' : '展开',
                    key: ValueKey(isExpanded),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 内容区域（使用 AnimatedSize 优化性能）
        // 只有展开时才构建内容，收起时只是一个空的 SizedBox
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded 
                ? Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: content,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraphWidget(ParagraphData paragraph, int paragraphIndex) {
    // 获取该段落的功德利益句高亮范围
    final meritSentences = _meritHighlights[paragraphIndex] ?? [];
    
    // 构建高亮字符索引集合
    final highlightedIndices = <int>{};
    for (final sentence in meritSentences) {
      for (int i = sentence.startOffset; i < sentence.endOffset && i < paragraph.chars.length; i++) {
        highlightedIndices.add(i);
      }
    }
    
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
        children: List.generate(paragraph.chars.length, (charIndex) {
          final isHighlighted = highlightedIndices.contains(charIndex);
          return _buildCharWidget(paragraph.chars[charIndex], isHighlighted: isHighlighted);
        }),
      ),
    );
  }

  Widget _buildCharWidget(CharData data, {bool isHighlighted = false}) {
    // 功德利益句高亮样式（金色）
    final highlightPinyinStyle = TextStyle(
      fontSize: 12,
      color: const Color(0xFFFFD700), // 金色
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    
    final highlightCharStyle = TextStyle(
      fontSize: 28,
      color: const Color(0xFFFFD700), // 金色
      fontWeight: FontWeight.w700,
      height: 1.2,
      shadows: const [
        Shadow(
          color: Color(0x66FFD700),
          blurRadius: 8,
        ),
      ],
    );
    
    switch (data.type) {
      case CharType.chinese:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.pinyin ?? '', 
                style: isHighlighted ? highlightPinyinStyle : _CachedWidgets.pinyinStyle,
              ),
              const SizedBox(height: 2),
              Text(
                data.char, 
                style: isHighlighted ? highlightCharStyle : _CachedWidgets.charStyle,
              ),
            ],
          ),
        );
      case CharType.space:
        return _CachedWidgets.spaceWidget;
      case CharType.punctuation:
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            data.char, 
            style: isHighlighted 
                ? highlightCharStyle.copyWith(fontSize: 28, shadows: null)
                : _CachedWidgets.punctuationStyle,
          ),
        );
      case CharType.other:
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            data.char,
            style: isHighlighted 
                ? highlightCharStyle.copyWith(fontSize: 24)
                : const TextStyle(
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

  // ============================================================================
  // 诵经结束仪式构建（回向）
  // ============================================================================

  Widget _buildSutraEpilogue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 补阙真言
        _buildPreludeSectionWithContent(
          SutraEpilogueData.buQueZhenYan['title']!,
          SutraEpilogueData.buQueZhenYan['pinyin']!,
          SutraEpilogueData.buQueZhenYan['times']!,
          SutraEpilogueData.buQueZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 2. 补阙圆满真言
        _buildPreludeSectionWithContent(
          SutraEpilogueData.buQueYuanManZhenYan['title']!,
          SutraEpilogueData.buQueYuanManZhenYan['pinyin']!,
          SutraEpilogueData.buQueYuanManZhenYan['times']!,
          SutraEpilogueData.buQueYuanManZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 3. 普回向真言
        _buildPreludeSectionWithContent(
          SutraEpilogueData.puHuiXiangZhenYan['title']!,
          SutraEpilogueData.puHuiXiangZhenYan['pinyin']!,
          SutraEpilogueData.puHuiXiangZhenYan['times']!,
          SutraEpilogueData.puHuiXiangZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 4. 回向偈
        _buildHuiXiangJi(),
        const SizedBox(height: 32),

        // 5. 三皈依
        _buildSanGuiYi(),
        const SizedBox(height: 24),

        // 结束说明
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              SutraEpilogueData.endingNote,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9370DB),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建回向偈
  Widget _buildHuiXiangJi() {
    final data = SutraEpilogueData.huiXiangJi;
    return Column(
      children: [
        _buildPreludeSectionTitle(data['title']!, data['pinyin']!),
        const SizedBox(height: 8),
        Text(
          '（${data['times']}）',
          style: const TextStyle(fontSize: 14, color: Color(0xFF9370DB)),
        ),
        const SizedBox(height: 20),
        // 八句偈 - 四列两两排列
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEpilogueVersePair(data['line1']!, data['line1Pinyin']!, data['line2']!, data['line2Pinyin']!),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEpilogueVersePair(data['line3']!, data['line3Pinyin']!, data['line4']!, data['line4Pinyin']!),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEpilogueVersePair(data['line5']!, data['line5Pinyin']!, data['line6']!, data['line6Pinyin']!),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEpilogueVersePair(data['line7']!, data['line7Pinyin']!, data['line8']!, data['line8Pinyin']!),
          ],
        ),
      ],
    );
  }

  /// 构建偈子成对显示（两句并排）
  Widget _buildEpilogueVersePair(String text1, String pinyin1, String text2, String pinyin2) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKaiJingLine(text1, pinyin1),
        const SizedBox(width: 24),
        _buildKaiJingLine(text2, pinyin2),
      ],
    );
  }

  /// 构建三皈依
  Widget _buildSanGuiYi() {
    final data = SutraEpilogueData.sanGuiYi;
    return Column(
      children: [
        _buildPreludeSectionTitle(data['title']!, data['pinyin']!),
        const SizedBox(height: 8),
        Text(
          '（${data['times']}）',
          style: const TextStyle(fontSize: 14, color: Color(0xFF9370DB)),
        ),
        const SizedBox(height: 20),
        // 三皈依佛
        _buildPreludeContentWithPinyin(data['content1']!),
        const SizedBox(height: 16),
        // 三皈依法
        _buildPreludeContentWithPinyin(data['content2']!),
        const SizedBox(height: 16),
        // 三皈依僧
        _buildPreludeContentWithPinyin(data['content3']!),
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
