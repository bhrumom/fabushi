import 'package:flutter/services.dart';

class BertTokenizer {
  final Map<String, int> vocab;
  final List<String> idsToTokens;
  final bool doLowerCase;

  BertTokenizer._(this.vocab, this.idsToTokens, {this.doLowerCase = true});

  static Future<BertTokenizer> fromAsset(
    String path, {
    bool doLowerCase = true,
  }) async {
    final vocabContent = await rootBundle.loadString(path);
    final vocabLines = vocabContent.split('\n');
    final vocab = <String, int>{};
    final idsToTokens = <String>[];

    for (var i = 0; i < vocabLines.length; i++) {
      final token = vocabLines[i].trim();
      if (token.isEmpty) continue;
      vocab[token] = i;
      idsToTokens.add(token);
    }

    return BertTokenizer._(vocab, idsToTokens, doLowerCase: doLowerCase);
  }

  List<int> encode(String text, {int maxLen = 512}) {
    final tokens = tokenize(text);
    final ids = convertTokensToIds(tokens);

    // Add [CLS] and [SEP]
    final clsId = vocab['[CLS]'] ?? 101;
    final sepId = vocab['[SEP]'] ?? 102;

    final truncatedIds = ids.length > maxLen - 2
        ? ids.sublist(0, maxLen - 2)
        : ids;
    return [clsId, ...truncatedIds, sepId];
  }

  List<String> tokenize(String text) {
    if (doLowerCase) {
      text = text.toLowerCase();
    }

    final List<String> tokens = [];
    // 1. Basic Tokenization: Handle CJK and whitespace
    final basicTokens = _basicTokenize(text);

    // 2. WordPiece Tokenization
    for (final token in basicTokens) {
      tokens.addAll(_wordPieceTokenize(token));
    }

    return tokens;
  }

  List<int> convertTokensToIds(List<String> tokens) {
    final unkId = vocab['[UNK]'] ?? 100;
    return tokens.map((t) => vocab[t] ?? unkId).toList();
  }

  List<String> _basicTokenize(String text) {
    final cleaned = _cleanText(text);
    final tokens = <String>[];

    final buffer = StringBuffer();
    for (final char in cleaned.runes) {
      final s = String.fromCharCode(char);
      if (_isCJK(char)) {
        if (buffer.isNotEmpty) {
          tokens.addAll(
            buffer.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
          );
          buffer.clear();
        }
        tokens.add(s);
      } else if (_isWhitespace(char)) {
        if (buffer.isNotEmpty) {
          tokens.addAll(
            buffer.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
          );
          buffer.clear();
        }
      } else {
        buffer.write(s);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.addAll(
        buffer.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
      );
    }

    return tokens;
  }

  String _cleanText(String text) {
    // Simple generic cleanup: remove control matchers apart from \t\n\r which are whitespace
    // For BERT, usually we replace all whitespace with space
    return text.replaceAll(RegExp(r'\s'), ' ');
  }

  List<String> _wordPieceTokenize(String text) {
    final outputTokens = <String>[];
    if (text.length > 200) {
      outputTokens.add('[UNK]');
      return outputTokens;
    }

    bool isBad = false;
    int start = 0;
    final subTokens = <String>[];

    while (start < text.length) {
      int end = text.length;
      String? curSubStr;

      while (start < end) {
        String sub = text.substring(start, end);
        if (start > 0) {
          sub = "##$sub";
        }
        if (vocab.containsKey(sub)) {
          curSubStr = sub;
          break;
        }
        end--;
      }

      if (curSubStr == null) {
        isBad = true;
        break;
      }

      subTokens.add(curSubStr);
      start = end;
    }

    if (isBad) {
      outputTokens.add('[UNK]');
    } else {
      outputTokens.addAll(subTokens);
    }
    return outputTokens;
  }

  bool _isCJK(int charCode) {
    return (charCode >= 0x4E00 && charCode <= 0x9FFF) ||
        (charCode >= 0x3400 && charCode <= 0x4DBF) ||
        (charCode >= 0x20000 && charCode <= 0x2A6DF) ||
        (charCode >= 0x2A700 && charCode <= 0x2B73F) ||
        (charCode >= 0x2B740 && charCode <= 0x2B81F) ||
        (charCode >= 0x2B820 && charCode <= 0x2CEAF) ||
        (charCode >= 0xF900 && charCode <= 0xFAFF) ||
        (charCode >= 0x2F800 && charCode <= 0x2FA1F);
  }

  bool _isWhitespace(int charCode) {
    // Basic whitespace check
    return charCode == 32 || charCode == 9 || charCode == 10 || charCode == 13;
  }
}
