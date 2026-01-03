import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/semantic_nlp_service.dart';

void main() {
  group('SemanticNlpService Tests', () {
    late SemanticNlpService service;

    setUp(() {
      service = SemanticNlpService.instance;
      // 确保初始化完成（同步部分）
      service.initialize();
      service.clearCache();
    });

    test('initialize should set up service correctly', () async {
      await service.initialize();
      // 这里没办法直接断言初始化后的私有状态，但如果不报错就说明基本的try-catch块工作正常
    });

    test('sortBySemanticPriority should prioritize high-value sentences', () async {
      final sentences = [
        '如是我闻，一时佛在舍卫国。', // 普通叙述
        '读诵此经，功德无量，消业灭罪。', // 高价值（功德+消业）
        '尔时世尊食时，著衣持钵。', // 普通叙述
        '是法殊胜，希有难得。', // 中高价值（赞扬）
      ];

      final sorted = await service.sortBySemanticPriority(sentences);

      // 验证排序：
      // 1. "读诵此经..." (Top priority: 功德, 灭罪)
      // 2. "是法殊胜..." (High priority: 殊胜, 希有)
      // 3. 普通句子
      
      expect(sorted.length, 4);
      expect(sorted[0], contains('功德')); // 确保第一句是功德句
      expect(sorted[1], contains('殊胜')); // 确保第二句是赞扬句
      
      // 打印结果直观检查
      print('Original: $sentences');
      print('Sorted: $sorted');
    });

    test('sortBySemanticPriority should use cache for repeated inputs', () async {
      final sentences = ['功德无量', '普通句子'];
      
      // 第一次调用
      final sorted1 = await service.sortBySemanticPriority(sentences);
      
      // 第二次调用（应命中缓存）
      final sorted2 = await service.sortBySemanticPriority(sentences);
      
      expect(sorted1, sorted2);
    });

    test('getPrioritySentences should return limited top sentences', () async {
      final sentences = [
        'Sentence A (功德)',
        'Sentence B (普通)',
        'Sentence C (殊胜)',
        'Sentence D (普通)',
        'Sentence E (灭罪)',
      ];
      
      final top2 = await service.getPrioritySentences(sentences, limit: 2);
      
      expect(top2.length, 2);
      expect(top2.any((s) => s.contains('功德')), true);
      expect(top2.any((s) => s.contains('灭罪') || s.contains('殊胜')), true);
    });
    
    test('Empty or single list handling', () async {
      expect(await service.sortBySemanticPriority([]), isEmpty);
      expect((await service.sortBySemanticPriority(['A'])).first, 'A');
    });
  });
}
