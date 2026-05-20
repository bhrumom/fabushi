import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';

/// 人工校订的功德利益完整语义单元。
///
/// 通用 X-Algo 负责快速召回大多数经文；部分经典（例如《金刚经》）
/// 的功德利益常以多个相邻句共同成义。这里保留人工判定的语义边界，
/// 运行时再从当前经文全文按锚点抽取原文，避免手抄漏字或输出残缺片段。
class CuratedMeritBenefitService {
  static CuratedMeritBenefitService? _instance;
  static CuratedMeritBenefitService get instance =>
      _instance ??= CuratedMeritBenefitService._();
  CuratedMeritBenefitService._();

  MeritBenefitData? analyzeFullText(
    String fullText,
    SutraTableOfContents toc,
  ) {
    if (_looksLikeT0235(fullText)) {
      final sentences = _extractSpans(fullText, toc, _t0235Spans);
      if (sentences.isNotEmpty) return _buildData(sentences);
    }
    return null;
  }

  bool _looksLikeT0235(String fullText) {
    final normalized = _normalize(fullText);
    final hasTitle = normalized.contains('金剛般若波羅蜜經') ||
        normalized.contains('金刚般若波罗蜜经');
    final hasDiamondSutraSignature =
        normalized.contains('若復有人於此經中受持乃至四句偈等') ||
        normalized.contains('若复有人于此经中受持乃至四句偈等') ||
        normalized.contains('是經義不可思議果報亦不可思議') ||
        normalized.contains('是经义不可思议果报亦不可思议');
    return hasTitle || hasDiamondSutraSignature;
  }

  MeritBenefitData _buildData(List<MeritBenefitSentence> sentences) {
    final byChapter = <SutraChapter?, List<MeritBenefitSentence>>{};
    for (final sentence in sentences) {
      byChapter.putIfAbsent(sentence.chapter, () => []).add(sentence);
    }
    return MeritBenefitData(sentences: sentences, byChapter: byChapter);
  }

  List<MeritBenefitSentence> _extractSpans(
    String fullText,
    SutraTableOfContents toc,
    List<_CuratedSpan> spans,
  ) {
    final normalized = _normalizeWithIndex(fullText);
    final paragraphRanges = _paragraphRanges(fullText);
    final sentences = <MeritBenefitSentence>[];
    var normalizedCursor = 0;

    for (final span in spans) {
      final startNeedle = _normalize(span.startAnchor);
      final endNeedle = _normalize(span.endAnchor);
      final searchStart = normalizedCursor < 0
          ? 0
          : (normalizedCursor > normalized.text.length
              ? normalized.text.length
              : normalizedCursor);
      final startNormIndex = normalized.text.indexOf(startNeedle, searchStart);

      if (startNormIndex < 0) {
        sentences.add(_fallbackSentence(span, toc));
        continue;
      }

      final endNormIndex = normalized.text.indexOf(endNeedle, startNormIndex);
      if (endNormIndex < 0) {
        sentences.add(_fallbackSentence(span, toc));
        normalizedCursor = startNormIndex + startNeedle.length;
        continue;
      }

      final rawStart = normalized.rawOffsets[startNormIndex];
      final rawEnd =
          normalized.rawOffsets[endNormIndex + endNeedle.length - 1] + 1;
      final displayText = _cleanDisplayText(fullText.substring(rawStart, rawEnd));
      final paragraph = _paragraphForOffset(paragraphRanges, rawStart);
      final paragraphEndOffset = rawEnd <= paragraph.end
          ? rawEnd - paragraph.start
          : paragraph.text.length;

      sentences.add(
        MeritBenefitSentence(
          text: displayText.isEmpty ? span.fallbackText : displayText,
          paragraphIndex: paragraph.index,
          startOffset: rawStart - paragraph.start,
          endOffset: paragraphEndOffset,
          chapter: toc.getCurrentChapter(paragraph.index),
        ),
      );
      normalizedCursor = endNormIndex + endNeedle.length;
    }

    return sentences;
  }

  MeritBenefitSentence _fallbackSentence(
    _CuratedSpan span,
    SutraTableOfContents toc,
  ) {
    return MeritBenefitSentence(
      text: span.fallbackText,
      paragraphIndex: 0,
      startOffset: 0,
      endOffset: span.fallbackText.length,
      chapter: toc.getCurrentChapter(0),
    );
  }

  String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), '');

  String _cleanDisplayText(String value) =>
      value.replaceAll(RegExp(r'\s+'), '');

  _NormalizedText _normalizeWithIndex(String value) {
    final buffer = StringBuffer();
    final rawOffsets = <int>[];
    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (RegExp(r'\s').hasMatch(ch)) continue;
      buffer.write(ch);
      rawOffsets.add(i);
    }
    return _NormalizedText(buffer.toString(), rawOffsets);
  }

  List<_ParagraphRange> _paragraphRanges(String fullText) {
    final ranges = <_ParagraphRange>[];
    var start = 0;
    void addRange(int end) {
      final text = fullText.substring(start, end);
      if (text.trim().isNotEmpty) {
        ranges.add(_ParagraphRange(ranges.length, start, end, text));
      }
    }

    for (final match in RegExp(r'\n+').allMatches(fullText)) {
      addRange(match.start);
      start = match.end;
    }
    addRange(fullText.length);
    return ranges;
  }

  _ParagraphRange _paragraphForOffset(
    List<_ParagraphRange> ranges,
    int rawOffset,
  ) {
    for (final range in ranges) {
      if (rawOffset >= range.start && rawOffset <= range.end) return range;
    }
    return ranges.isEmpty ? _ParagraphRange(0, 0, 0, '') : ranges.first;
  }

  static final List<_CuratedSpan> _t0235Spans = [
    _CuratedSpan(
      startAnchor: "聞是章句，乃至一念生淨信者",
      endAnchor: "知悉見，是諸眾生得如是無量福德。",
      fallbackText: "聞是章句，乃至一念生淨信者，須菩提！如來悉知悉見，是諸眾生得如是無量福德。",
    ),
    _CuratedSpan(
      startAnchor: "若人滿三千大千世界七寶以用布施",
      endAnchor: "耨多羅三藐三菩提法，皆從此經出。",
      fallbackText: "若人滿三千大千世界七寶以用布施，是人所得福德甚多；若復有人，於此經中受持乃至四句偈等，為他人說，其福勝彼。何以故？一切諸佛及諸佛阿耨多羅三藐三菩提法，皆從此經出。",
    ),
    _CuratedSpan(
      startAnchor: "以七寶滿爾所恒河沙數三千大千世界以用布施",
      endAnchor: "等，為他人說，而此福德勝前福德。",
      fallbackText: "若有善男子、善女人，以七寶滿爾所恒河沙數三千大千世界以用布施，得福甚多；若善男子、善女人於此經中，乃至受持四句偈等，為他人說，而此福德勝前福德。",
    ),
    _CuratedSpan(
      startAnchor: "隨說是經，乃至四句偈等",
      endAnchor: "如佛塔廟；何況有人盡能受持讀誦？",
      fallbackText: "隨說是經，乃至四句偈等，當知此處，一切世間天、人、阿修羅皆應供養，如佛塔廟；何況有人盡能受持讀誦？",
    ),
    _CuratedSpan(
      startAnchor: "成就最上、第一、希有之法",
      endAnchor: "所在之處，則為有佛，若尊重弟子。",
      fallbackText: "若有人盡能受持讀誦，當知是人成就最上、第一、希有之法；若是經典所在之處，則為有佛，若尊重弟子。",
    ),
    _CuratedSpan(
      startAnchor: "以恒河沙等身命布施",
      endAnchor: "持四句偈等，為他人說，其福甚多。",
      fallbackText: "若有善男子、善女人，以恒河沙等身命布施；若復有人，於此經中，乃至受持四句偈等，為他人說，其福甚多。",
    ),
    _CuratedSpan(
      startAnchor: "信心清淨，則生實相",
      endAnchor: "相，當知是人，成就第一希有功德。",
      fallbackText: "若復有人得聞是經，信心清淨，則生實相，當知是人，成就第一希有功德。",
    ),
    _CuratedSpan(
      startAnchor: "得聞是經，信解、受持",
      endAnchor: "，信解、受持，是人則為第一希有。",
      fallbackText: "若當來世後五百歲，其有眾生得聞是經，信解、受持，是人則為第一希有。",
    ),
    _CuratedSpan(
      startAnchor: "得聞是經，不驚、不怖、不畏",
      endAnchor: "、不怖、不畏，當知是人甚為希有。",
      fallbackText: "若復有人得聞是經，不驚、不怖、不畏，當知是人甚為希有。",
    ),
    _CuratedSpan(
      startAnchor: "能於此經受持、讀誦",
      endAnchor: "悉見是人，皆得成就無量無邊功德。",
      fallbackText: "當來之世，若有善男子、善女人，能於此經受持、讀誦，則為如來以佛智慧悉知是人，悉見是人，皆得成就無量無邊功德。",
    ),
    _CuratedSpan(
      startAnchor: "初日分以恒河沙等身布施",
      endAnchor: "何況書寫、受持、讀誦、為人解說。",
      fallbackText: "若有善男子、善女人，初日分以恒河沙等身布施，中日分復以恒河沙等身布施，後日分亦以恒河沙等身布施，如是無量百千萬億劫以身布施；若復有人，聞此經典，信心不逆，其福勝彼，何況書寫、受持、讀誦、為人解說。",
    ),
    _CuratedSpan(
      startAnchor: "是經有不可思議、不可稱量、無邊功德",
      endAnchor: "來為發大乘者說，為發最上乘者說。",
      fallbackText: "是經有不可思議、不可稱量、無邊功德。如來為發大乘者說，為發最上乘者說。",
    ),
    _CuratedSpan(
      startAnchor: "若有人能受持、讀誦、廣為人說",
      endAnchor: "則為荷擔如來阿耨多羅三藐三菩提。",
      fallbackText: "若有人能受持、讀誦、廣為人說，如來悉知是人，悉見是人，皆得成就不可量、不可稱、無有邊、不可思議功德；如是人等，則為荷擔如來阿耨多羅三藐三菩提。",
    ),
    _CuratedSpan(
      startAnchor: "在在處處若有此經",
      endAnchor: "、作禮、圍繞，以諸華香而散其處。",
      fallbackText: "在在處處若有此經，一切世間天、人、阿修羅所應供養；當知此處則為是塔，皆應恭敬、作禮、圍繞，以諸華香而散其處。",
    ),
    _CuratedSpan(
      startAnchor: "先世罪業則為消滅",
      endAnchor: "為消滅，當得阿耨多羅三藐三菩提。",
      fallbackText: "善男子、善女人受持、讀誦此經，若為人輕賤，是人先世罪業應墮惡道，以今世人輕賤故，先世罪業則為消滅，當得阿耨多羅三藐三菩提。",
    ),
    _CuratedSpan(
      startAnchor: "得值八百四千萬億那由他諸佛",
      endAnchor: "千萬億分乃至算數、譬喻所不能及。",
      fallbackText: "佛於過去無量阿僧祇劫，在然燈佛前得值八百四千萬億那由他諸佛，悉皆供養承事，無空過者；若復有人於後末世能受持、讀誦此經，所得功德，於佛所供養諸佛功德，百分不及一，千萬億分乃至算數、譬喻所不能及。",
    ),
    _CuratedSpan(
      startAnchor: "有受持、讀誦此經所得功德",
      endAnchor: "是經義不可思議，果報亦不可思議。",
      fallbackText: "若善男子、善女人於後末世，有受持、讀誦此經所得功德，若具說者，或有人聞，心則狂亂，狐疑不信；當知是經義不可思議，果報亦不可思議。",
    ),
    _CuratedSpan(
      startAnchor: "所有諸須彌山王，如是等七寶聚",
      endAnchor: "萬億分，乃至算數、譬喻所不能及。",
      fallbackText: "若三千大千世界中所有諸須彌山王，如是等七寶聚，有人持用布施；若人以此《般若波羅蜜經》，乃至四句偈等，受持、讀誦、為他人說，於前福德百分不及一，百千萬億分，乃至算數、譬喻所不能及。",
    ),
    _CuratedSpan(
      startAnchor: "若菩薩以滿恒河沙等世界七寶布施",
      endAnchor: "德。須菩提！以諸菩薩不受福德故。",
      fallbackText: "若菩薩以滿恒河沙等世界七寶布施；若復有人知一切法無我，得成於忍，此菩薩勝前菩薩所得功德。須菩提！以諸菩薩不受福德故。",
    ),
    _CuratedSpan(
      startAnchor: "菩薩所作福德，不應貪著",
      endAnchor: "福德，不應貪著，是故說不受福德。",
      fallbackText: "菩薩所作福德，不應貪著，是故說不受福德。",
    ),
    _CuratedSpan(
      startAnchor: "滿無量阿僧祇世界七寶持用布施",
      endAnchor: "何為人演說？不取於相，如如不動。",
      fallbackText: "若有人以滿無量阿僧祇世界七寶持用布施；若有善男子、善女人發菩薩心者，持於此經乃至四句偈等，受持、讀誦、為人演說，其福勝彼。云何為人演說？不取於相，如如不動。",
    ),
  ];
}

class _CuratedSpan {
  final String startAnchor;
  final String endAnchor;
  final String fallbackText;

  const _CuratedSpan({
    required this.startAnchor,
    required this.endAnchor,
    required this.fallbackText,
  });
}

class _NormalizedText {
  final String text;
  final List<int> rawOffsets;

  const _NormalizedText(this.text, this.rawOffsets);
}

class _ParagraphRange {
  final int index;
  final int start;
  final int end;
  final String text;

  const _ParagraphRange(this.index, this.start, this.end, this.text);
}
