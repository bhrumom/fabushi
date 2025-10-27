import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:gbk_codec/gbk_codec.dart';
import 'package:global_dharma_sharing/config/unified_config.dart';

class CloudflareTextService {
  static final _random = Random();
  static const String baseUrl = 'https://flutter.ombhrum.com';
  
  // 硬编码的佛经文本内容
  static final List<Map<String, String>> _sampleTexts = [
    {
      'title': '心经',
      'content': '''观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。

舍利子，色不异空，空不异色，色即是空，空即是色，受想行识，亦复如是。

舍利子，是诸法空相，不生不灭，不垢不净，不增不减。是故空中无色，无受想行识，无眼耳鼻舌身意，无色声香味触法，无眼界，乃至无意识界。

无无明，亦无无明尽，乃至无老死，亦无老死尽。无苦集灭道，无智亦无得。以无所得故，菩提萨埵，依般若波罗蜜多故，心无挂碍。无挂碍故，无有恐怖，远离颠倒梦想，究竟涅槃。

三世诸佛，依般若波罗蜜多故，得阿耨多罗三藐三菩提。故知般若波罗蜜多，是大神咒，是大明咒，是无上咒，是无等等咒，能除一切苦，真实不虚。

故说般若波罗蜜多咒，即说咒曰：揭谛揭谛，波罗揭谛，波罗僧揭谛，菩提萨婆诃。'''
    },
    {
      'title': '大悲咒',
      'content': '''南无喝啰怛那哆啰夜耶。南无阿唎耶。婆卢羯帝烁钵啰耶。菩提萨埵婆耶。摩诃萨埵婆耶。摩诃迦卢尼迦耶。唵。萨皤啰罚曳。数怛那怛写。南无悉吉栗埵伊蒙阿唎耶。婆卢吉帝室佛啰愣驮婆。南无那啰谨墀。醯利摩诃皤哆沙咩。萨婆阿他豆输朋。阿逝孕。萨婆萨哆那摩婆萨哆那摩婆伽。摩罚特豆。怛侄他。唵阿婆卢醯。卢迦帝。迦罗帝。夷醯唎。摩诃菩提萨埵。萨婆萨婆。摩啰摩啰。摩醯摩醯唎驮孕。俱卢俱卢羯蒙。度卢度卢罚阇耶帝。摩诃罚阇耶帝。陀啰陀啰。地唎尼。室佛啰耶。遮啰遮啰。摩么罚摩啰。穆帝隶。伊醯伊醯。室那室那。阿啰参佛啰舍利。罚沙罚参。佛啰舍耶。呼嚧呼嚧摩啰。呼嚧呼嚧醯利。娑啰娑啰。悉唎悉唎。苏嚧苏嚧。菩提夜菩提夜。菩驮夜菩驮夜。弥帝唎夜。那啰谨墀。地利瑟尼那。波夜摩那。娑婆诃。悉陀夜。娑婆诃。摩诃悉陀夜。娑婆诃。悉陀喻艺。室皤啰耶。娑婆诃。那啰谨墀。娑婆诃。摩啰那啰。娑婆诃。悉啰僧阿穆佉耶。娑婆诃。娑婆摩诃阿悉陀夜。娑婆诃。者吉啰阿悉陀夜。娑婆诃。波陀摩羯悉陀夜。娑婆诃。那啰谨墀皤伽啰耶。娑婆诃。摩婆利胜羯啰夜。娑婆诃。南无喝啰怛那哆啰夜耶。南无阿唎耶。婆嚧吉帝。烁皤啰夜。娑婆诃。唵悉殿都。漫多啰。跋陀耶。娑婆诃。'''
    },
    {
      'title': '金刚经',
      'content': '''如是我闻。一时，佛在舍卫国祇树给孤独园，与大比丘众千二百五十人俱。尔时，世尊食时，著衣持钵，入舍卫大城乞食。于其城中，次第乞已，还至本处。饭食讫，收衣钵，洗足已，敷座而坐。

时，长老须菩提在大众中即从座起，偏袒右肩，右膝著地，合掌恭敬而白佛言：「希有！世尊！如来善护念诸菩萨，善付嘱诸菩萨。世尊！善男子、善女人，发阿耨多罗三藐三菩提心，应云何住，云何降伏其心？」

佛言：「善哉，善哉。须菩提！如汝所说，如来善护念诸菩萨，善付嘱诸菩萨。汝今谛听！当为汝说：善男子、善女人，发阿耨多罗三藐三菩提心，应如是住，如是降伏其心。」

「唯然。世尊！愿乐欲闻。」

佛告须菩提：「诸菩萨摩诃萨应如是降伏其心！所有一切众生之类：若卵生、若胎生、若湿生、若化生；若有色、若无色；若有想、若无想、若非有想非无想，我皆令入无余涅槃而灭度之。如是灭度无量无数无边众生，实无众生得灭度者。何以故？须菩提！若菩萨有我相、人相、众生相、寿者相，即非菩萨。」'''
    },
    {
      'title': '六字真言',
      'content': '''唵嘛呢叭咪吽

此六字大明咒，是观世音菩萨的微妙本心，若有知是微妙本心即知解脱。

唵：表示佛部心，代表法、报、化三身，也可以说成三金刚（身金刚、语金刚、意金刚），是所有诸佛菩萨的智慧身、语、意。

嘛呢：表示宝部心，就是摩尼宝珠，取之不尽、用之不竭、随心所愿、无不满足，向它祈求自然会得到精神需求和各种物质财富。

叭咪：表示莲花部心，就是出污泥而不染的莲花，表示现代人虽处于五浊恶世的轮回中，但诵此真言，就能去除烦恼，获得清净。

吽：表示金刚部心，是祈愿成就的意思，必须依靠佛的力量，才能循序渐进、勤勉修行、普渡众生、成就一切，最后达到佛的境界。

诵持此咒，能除一切痛苦，能破除一切邪恶，能治一切疾病，能成就一切善法，能消除一切灾难。'''
    },
    {
      'title': '普贤菩萨行愿品',
      'content': '''尔时，普贤菩萨摩诃萨，称赞如来胜功德已，告诸菩萨及善财言：「善男子！如来功德，假使十方一切诸佛，经不可说不可说佛刹极微尘数劫，相续演说，不可穷尽！若欲成就此功德门，应修十种广大行愿。何等为十？

一者、礼敬诸佛。
二者、称赞如来。
三者、广修供养。
四者、忏悔业障。
五者、随喜功德。
六者、请转法轮。
七者、请佛住世。
八者、常随佛学。
九者、恒顺众生。
十者、普皆回向。

善财白言：「大圣！云何礼敬乃至回向？」

普贤菩萨告善财言：「善男子！言礼敬诸佛者，所有尽法界、虚空界，十方三世一切佛刹，极微尘数诸佛世尊，我以普贤行愿力故，深心信解，如对目前，悉以清净身语意业，常修礼敬。一一佛所，皆现不可说不可说佛刹极微尘数身。一一身，遍礼不可说不可说佛刹极微尘数佛。虚空界尽，我礼乃尽，以虚空界不可尽故，我此礼敬无有穷尽。如是乃至众生界尽，众生业尽，众生烦恼尽，我礼乃尽。而众生界乃至烦恼无有尽故，我此礼敬无有穷尽。念念相续，无有间断，身语意业，无有疲厌。」'''
    },
  ];

  /// 获取随机文本内容（用于信息流）
  Future<Map<String, dynamic>?> getRandomTextContent() async {
    try {
      // 尝试从云端获取
      final cloudText = await _getCloudTextContent();
      if (cloudText != null) {
        return cloudText;
      }
      
      // 云端失败，使用本地内容
      final selectedText = _sampleTexts[_random.nextInt(_sampleTexts.length)];
      print('Using local text: ${selectedText['title']}');
      return selectedText;
    } catch (e) {
      print('Error getting random text content: $e');
      // 出错时返回本地内容
      return _sampleTexts[_random.nextInt(_sampleTexts.length)];
    }
  }
  
  /// 从云端获取文本内容
  Future<Map<String, dynamic>?> _getCloudTextContent() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/asset-manifest.json'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> manifest = json.decode(response.body);
        final txtFiles = manifest
            .where((item) => item['key']?.toString().endsWith('.txt') == true)
            .map((item) => item['key'].toString())
            .toList();
        
        if (txtFiles.isNotEmpty) {
          txtFiles.shuffle();
          final selectedFile = txtFiles.first;
          
          final contentResponse = await http.get(
            Uri.parse('$baseUrl/$selectedFile'),
          ).timeout(const Duration(seconds: 10));
          
          if (contentResponse.statusCode == 200) {
            // 文件是GBK编码，直接使用GBK解码
            String content;
            try {
              content = gbk_bytes.decode(contentResponse.bodyBytes);
              print('Successfully decoded GBK content: ${content.length} chars');
            } catch (e) {
              print('GBK decoding failed: $e, trying UTF-8');
              content = utf8.decode(contentResponse.bodyBytes, allowMalformed: true);
            }
            final fileName = selectedFile.split('/').last.replaceAll('.txt', '');
            // 清理反编译器水印
            content = _cleanDecompilerWatermark(content);
            print('Loaded cloud text: $fileName');
            return {
              'title': fileName,
              'content': content,
              'filePath': selectedFile,
            };
          }
        }
      }
    } catch (e) {
      print('Cloud text fetch failed: $e');
    }
    return null;
  }
  
  /// 清理反编译器水印
  static String _cleanDecompilerWatermark(String content) {
    // 移除CHM反编译器水印
    final watermarkPattern = RegExp(
      r'This file is decompiled by an unregistered version of ChmDecompiler\..*?http://\s*www\.etextwizard\.com/',
      multiLine: true,
      dotAll: true,
    );
    content = content.replaceAll(watermarkPattern, '');
    
    // 移除常见的变体
    content = content.replaceAll(
      RegExp(r'This file is decompiled.*?etextwizard\.com/', multiLine: true, dotAll: true),
      '',
    );
    
    return content.trim();
  }
  
  /// 获取所有文本列表
  Future<List<Map<String, String>>> getAllTexts() async {
    return _sampleTexts;
  }
}
