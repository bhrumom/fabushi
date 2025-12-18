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
    '爇': 'ruò',     // 香赞中"乍爇"
    '薰': 'xūn',     // 香赞中"蒙薰"
    '殷': 'yīn',     // 香赞中"方殷"
    '唎': 'lì',      // 真言中
    '驮': 'tuó',     // 真言中
    '喃': 'nán',     // 真言中
    '噜': 'lū',      // 真言中
    '嗡': 'ōng',     // 真言中
    '曩': 'nǎng',    // 真言中
    '斛': 'hòng',    // 真言中
    '誐': 'yé',      // 真言中
  };
}

/// 诵经前仪式内容数据
class SutraPreludeData {
  /// 诵经警文
  static const List<String> jingWen = [
    '1、未诵前，漱口，濯手。当净三业，若三业无亏，则百福俱集。三业者，身、口、意也。端身正坐，如对圣容，则身业净也。口无杂言，断诸嬉笑，则口业净也。意不散乱，屏息万缘，则意业净也。',
    '2、未诵前，已诵后，俱要对圣像前合掌三礼。如无佛像，对经、对空礼拜亦可。',
  ];

  /// 香赞
  static const Map<String, String> xiangZan = {
    'title': '香赞',
    'pinyin': 'xiāng zàn',
    'times': '一遍',
    'content': '炉香乍爇．法界蒙薰．诸佛海会悉遥闻．随处结祥云．诚意方殷．诸佛现全身。',
    'ending': '南無香云盖菩萨摩诃萨',
    'endingNote': '合掌三称',
  };

  /// 净口业真言
  static const Map<String, String> jingKouYeZhenYan = {
    'title': '净口业真言',
    'pinyin': 'jìng kǒu yè zhēn yán',
    'times': '三遍',
    'content': '唵．修唎修唎．摩诃修唎．修修唎．萨婆诃。',
  };

  /// 净三业真言
  static const Map<String, String> jingSanYeZhenYan = {
    'title': '净三业真言',
    'pinyin': 'jìng sān yè zhēn yán',
    'times': '三遍',
    'content': '唵．娑嚩．婆嚩秫驮．娑嚩达摩娑嚩．婆嚩秫度憾。',
  };

  /// 安土地真言
  static const Map<String, String> anTuDiZhenYan = {
    'title': '安土地真言',
    'pinyin': 'ān tǔ dì zhēn yán',
    'times': '三遍',
    'content': '南無三满哆．母驮喃．唵度噜度噜．地尾．娑婆诃。',
  };

  /// 普供养真言
  static const Map<String, String> puGongYangZhenYan = {
    'title': '普供养真言',
    'pinyin': 'pǔ gòng yǎng zhēn yán',
    'times': '三遍',
    'content': '唵．誐誐曩．三婆嚩．嚩日啰斛。',
  };

  /// 南無本师释迦牟尼佛
  static const Map<String, String> naMoBenShiFo = {
    'title': '南無本师释迦牟尼佛',
    'pinyin': 'ná mó běn shī shì jiā móu ní fó',
    'note': '合掌三称',
  };

  /// 开经偈
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === 诵经前仪式 (Sutra Reading Prelude) ===
              _buildSutraPrelude(),
              const SizedBox(height: 32),
              // 分隔线
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
              // === 经文正文 ===
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
              _buildPinyinText(fullText),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建诵经前仪式完整内容
  Widget _buildSutraPrelude() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 诵经警文
        _buildPreludeSectionTitle('诵经警文', 'sòng jīng jǐng wén'),
        const SizedBox(height: 16),
        ...SutraPreludeData.jingWen.map((text) => _buildJingWenParagraph(text)),
        const SizedBox(height: 32),

        // 2. 香赞
        _buildPreludeSectionWithContent(
          SutraPreludeData.xiangZan['title']!,
          SutraPreludeData.xiangZan['pinyin']!,
          SutraPreludeData.xiangZan['times']!,
          SutraPreludeData.xiangZan['content']!,
          ending: SutraPreludeData.xiangZan['ending'],
          endingNote: SutraPreludeData.xiangZan['endingNote'],
        ),
        const SizedBox(height: 32),

        // 3. 净口业真言
        _buildPreludeSectionWithContent(
          SutraPreludeData.jingKouYeZhenYan['title']!,
          SutraPreludeData.jingKouYeZhenYan['pinyin']!,
          SutraPreludeData.jingKouYeZhenYan['times']!,
          SutraPreludeData.jingKouYeZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 4. 净三业真言
        _buildPreludeSectionWithContent(
          SutraPreludeData.jingSanYeZhenYan['title']!,
          SutraPreludeData.jingSanYeZhenYan['pinyin']!,
          SutraPreludeData.jingSanYeZhenYan['times']!,
          SutraPreludeData.jingSanYeZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 5. 安土地真言
        _buildPreludeSectionWithContent(
          SutraPreludeData.anTuDiZhenYan['title']!,
          SutraPreludeData.anTuDiZhenYan['pinyin']!,
          SutraPreludeData.anTuDiZhenYan['times']!,
          SutraPreludeData.anTuDiZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 6. 普供养真言
        _buildPreludeSectionWithContent(
          SutraPreludeData.puGongYangZhenYan['title']!,
          SutraPreludeData.puGongYangZhenYan['pinyin']!,
          SutraPreludeData.puGongYangZhenYan['times']!,
          SutraPreludeData.puGongYangZhenYan['content']!,
        ),
        const SizedBox(height: 32),

        // 7. 南無本师释迦牟尼佛
        _buildNaMoSection(),
        const SizedBox(height: 32),

        // 8. 开经偈
        _buildKaiJingJi(),
      ],
    );
  }

  /// 构建诵经警文段落（说明文字用紫色）
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
          color: Color(0xFF9370DB), // 紫色说明文字
          height: 1.8,
        ),
      ),
    );
  }

  /// 构建仪式标题（红色标题 + 拼音）
  Widget _buildPreludeSectionTitle(String title, String pinyin) {
    return Center(
      child: Column(
        children: [
          Text(
            pinyin,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9370DB), // 紫色拼音
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFFDC143C), // 红色标题
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建带内容的仪式区块
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
        // 标题区
        _buildPreludeSectionTitle(title, titlePinyin),
        const SizedBox(height: 8),
        // 次数说明
        Text(
          '（$times）',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9370DB), // 紫色
          ),
        ),
        const SizedBox(height: 16),
        // 内容 - 带拼音的汉字
        _buildPreludeContentWithPinyin(content),
        // 结尾语（如有）
        if (ending != null) ...[
          const SizedBox(height: 20),
          _buildPreludeEndingWithPinyin(ending, endingNote),
        ],
      ],
    );
  }

  /// 构建仪式内容的拼音文本
  Widget _buildPreludeContentWithPinyin(String text) {
    final List<Widget> charWidgets = [];
    int i = 0;

    while (i < text.length) {
      final char = text[i];

      // 尝试匹配佛教专用词组
      final matchResult = _matchBuddhistPhrase(text, i);

      if (matchResult != null) {
        final phrase = matchResult['phrase'] as String;
        final pinyinList = matchResult['pinyin'] as List<String>;
        for (int j = 0; j < phrase.length; j++) {
          charWidgets.add(_buildPreludeCharWithPinyin(phrase[j], pinyinList[j]));
        }
        i += phrase.length;
      } else if (_isChinese(char)) {
        String pinyin = BuddhistPinyinDictionary.singleCharOverride[char] ??
            PinyinHelper.getPinyin(char, separator: '', format: PinyinFormat.WITH_TONE_MARK);
        charWidgets.add(_buildPreludeCharWithPinyin(char, pinyin));
        i++;
      } else if (char == '．' || char == '。' || char == '，') {
        charWidgets.add(_buildPreludePunctuation(char));
        i++;
      } else if (char == ' ' || char == '\t') {
        charWidgets.add(const SizedBox(width: 8));
        i++;
      } else if (_isPunctuation(char)) {
        charWidgets.add(_buildPreludePunctuation(char));
        i++;
      } else {
        charWidgets.add(_buildPreludeNonChineseChar(char));
        i++;
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 28,
      children: charWidgets,
    );
  }

  /// 构建仪式汉字 - 紫色拼音 + 深红色汉字
  Widget _buildPreludeCharWithPinyin(String char, String pinyin) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pinyin,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9370DB), // 紫色拼音
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            char,
            style: const TextStyle(
              fontSize: 26,
              color: Color(0xFFB22222), // 深红色汉字
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建仪式标点
  Widget _buildPreludePunctuation(String char) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 26,
          color: Color(0xFFB22222), // 深红色
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// 构建仪式非中文字符
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

  /// 构建仪式结尾语（如"南無香云盖菩萨摩诃萨"）
  Widget _buildPreludeEndingWithPinyin(String ending, String? note) {
    return Column(
      children: [
        _buildPreludeContentWithPinyin(ending),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            '（$note）',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFDC143C), // 红色
            ),
          ),
        ],
      ],
    );
  }

  /// 构建南無本师释迦牟尼佛区块
  Widget _buildNaMoSection() {
    final data = SutraPreludeData.naMoBenShiFo;
    return Column(
      children: [
        // 拼音
        Text(
          data['pinyin']!,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9370DB), // 紫色
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // 汉字 - 大红色
        _buildPreludeContentWithPinyin(data['title']!),
        const SizedBox(height: 8),
        Text(
          '（${data['note']}）',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFDC143C), // 红色
          ),
        ),
      ],
    );
  }

  /// 构建开经偈
  Widget _buildKaiJingJi() {
    final data = SutraPreludeData.kaiJingJi;
    return Column(
      children: [
        _buildPreludeSectionTitle(data['title']!, data['pinyin']!),
        const SizedBox(height: 8),
        Text(
          '（${data['times']}）',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9370DB),
          ),
        ),
        const SizedBox(height: 20),
        // 四句偈
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

  /// 构建开经偈单行
  Widget _buildKaiJingLine(String text, String pinyin) {
    return Column(
      children: [
        Text(
          pinyin,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9370DB), // 紫色拼音
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 24,
            color: Color(0xFFB22222), // 深红色
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ],
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
