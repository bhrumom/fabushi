import 'package:lpinyin/lpinyin.dart';

class RecitationMatchEvent {
  final int countDelta;
  final double progress;
  final String hint;

  const RecitationMatchEvent({
    required this.countDelta,
    required this.progress,
    required this.hint,
  });
}

class RecitationProgressMatcher {
  RecitationProgressMatcher(
    String targetText, {
    DateTime Function()? now,
    this.shortTokenLimit = 120,
    this.longCompletionThreshold = 0.92,
    this.shortCompletionThreshold = 0.78,
    this.cooldown = const Duration(milliseconds: 1200),
  }) : _now = now ?? DateTime.now {
    _targetTokens = _toPinyinTokens(targetText);
  }

  final DateTime Function() _now;
  final int shortTokenLimit;
  final double longCompletionThreshold;
  final double shortCompletionThreshold;
  final Duration cooldown;

  late final List<String> _targetTokens;
  int _cursor = 0;
  DateTime? _lastCountAt;
  String _lastText = '';

  bool get isReady => _targetTokens.isNotEmpty;
  bool get isShortPractice => _targetTokens.length <= shortTokenLimit;
  double get progress =>
      _targetTokens.isEmpty ? 0 : (_cursor / _targetTokens.length).clamp(0, 1);

  void reset() {
    _cursor = 0;
    _lastCountAt = null;
    _lastText = '';
  }

  RecitationMatchEvent accept(
    String recognizedText, {
    bool isEndpoint = false,
  }) {
    if (_targetTokens.isEmpty) {
      return const RecitationMatchEvent(
        countDelta: 0,
        progress: 0,
        hint: '尚未加载功课本',
      );
    }

    final incoming = _dedupeIncrement(recognizedText);
    final tokens = _toPinyinTokens(
      incoming.isEmpty ? recognizedText : incoming,
    );
    if (tokens.isEmpty) {
      return RecitationMatchEvent(
        countDelta: 0,
        progress: progress,
        hint: '等待识别正文',
      );
    }

    if (isShortPractice) {
      return _acceptShortPractice(tokens, isEndpoint: isEndpoint);
    }

    final match = _bestWindowMatch(tokens);
    if (match.score >= 0.42) {
      _cursor = _cursor > match.nextCursor ? _cursor : match.nextCursor;
    }

    if (progress >= longCompletionThreshold && _canCount()) {
      _lastCountAt = _now();
      _cursor = 0;
      return const RecitationMatchEvent(
        countDelta: 1,
        progress: 1,
        hint: '已识别完成一遍',
      );
    }

    return RecitationMatchEvent(
      countDelta: 0,
      progress: progress,
      hint: match.score >= 0.42 ? '正在跟随功课本' : '继续念诵',
    );
  }

  RecitationMatchEvent _acceptShortPractice(
    List<String> tokens, {
    required bool isEndpoint,
  }) {
    final lcs = _longestCommonSubsequenceLength(tokens, _targetTokens);
    final score = lcs / _targetTokens.length;
    final shouldCount =
        score >= shortCompletionThreshold &&
        (isEndpoint || score >= 0.92) &&
        _canCount();

    if (shouldCount) {
      _lastCountAt = _now();
      return const RecitationMatchEvent(
        countDelta: 1,
        progress: 1,
        hint: '已识别一遍',
      );
    }

    return RecitationMatchEvent(
      countDelta: 0,
      progress: score.clamp(0, 1),
      hint: score >= 0.5 ? '即将完成一遍' : '正在识别',
    );
  }

  _WindowMatch _bestWindowMatch(List<String> tokens) {
    final start = (_cursor - 30).clamp(0, _targetTokens.length);
    final end = (_cursor + tokens.length + 180).clamp(0, _targetTokens.length);
    var best = _WindowMatch(score: 0, nextCursor: 0, startCursor: _cursor);

    for (var i = start; i < end; i++) {
      final sliceEnd = (i + tokens.length + 12).clamp(0, _targetTokens.length);
      if (sliceEnd <= i) continue;
      final window = _targetTokens.sublist(i, sliceEnd);
      final lcs = _longestCommonSubsequenceLength(tokens, window);
      final score = lcs / tokens.length;
      final nextCursor = i + lcs;
      final isBetterScore = score > best.score + 0.000001;
      final distance = (i - _cursor).abs();
      final bestDistance = (best.startCursor - _cursor).abs();
      final isForwardTie =
          (score - best.score).abs() <= 0.000001 &&
          (distance < bestDistance ||
              (distance == bestDistance && nextCursor > best.nextCursor));
      if (isBetterScore || isForwardTie) {
        best = _WindowMatch(
          score: score,
          nextCursor: nextCursor,
          startCursor: i,
        );
      }
    }

    return best;
  }

  bool _canCount() {
    final last = _lastCountAt;
    if (last == null) return true;
    return _now().difference(last) >= cooldown;
  }

  String _dedupeIncrement(String text) {
    final current = _normalizeChineseAndAlpha(text);
    if (current.isEmpty) return '';
    final previous = _lastText;
    _lastText = current;

    if (previous.isEmpty) return current;
    if (current.startsWith(previous)) {
      return current.substring(previous.length);
    }
    if (previous.startsWith(current)) return '';
    return current;
  }

  static List<String> _toPinyinTokens(String text) {
    final normalized = _normalizeChineseAndAlpha(text);
    final tokens = <String>[];
    for (final codePoint in normalized.runes) {
      final char = String.fromCharCode(codePoint);
      if (_isChinese(codePoint)) {
        final pinyin = PinyinHelper.getPinyinE(
          char,
          defPinyin: '',
        ).replaceAll(RegExp(r'\s+'), '').toLowerCase();
        if (pinyin.isNotEmpty) tokens.add(pinyin);
      } else {
        tokens.add(char.toLowerCase());
      }
    }
    return tokens;
  }

  static String _normalizeChineseAndAlpha(String text) {
    final buffer = StringBuffer();
    for (final codePoint in text.runes) {
      final isAsciiAlphaNum =
          (codePoint >= 0x30 && codePoint <= 0x39) ||
          (codePoint >= 0x41 && codePoint <= 0x5a) ||
          (codePoint >= 0x61 && codePoint <= 0x7a);
      if (_isChinese(codePoint) || isAsciiAlphaNum) {
        buffer.writeCharCode(codePoint);
      }
    }
    return buffer.toString();
  }

  static bool _isChinese(int codePoint) {
    return codePoint >= 0x4e00 && codePoint <= 0x9fff;
  }

  static int _longestCommonSubsequenceLength(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      var prev = 0;
      for (var j = 1; j <= b.length; j++) {
        final temp = dp[j];
        if (a[i - 1] == b[j - 1]) {
          dp[j] = prev + 1;
        } else if (dp[j - 1] > dp[j]) {
          dp[j] = dp[j - 1];
        }
        prev = temp;
      }
    }
    return dp[b.length];
  }
}

class _WindowMatch {
  final double score;
  final int nextCursor;
  final int startCursor;

  const _WindowMatch({
    required this.score,
    required this.nextCursor,
    required this.startCursor,
  });
}
