class SearchUtils {
  static const _chineseNums = [
    '零',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
  ];
  static const _chineseUnits = ['', '十', '百', '千', '万'];

  /// 将文本中的阿拉伯数字转换为中文数字
  /// 目前主要处理 0-99 的数字，用于经卷搜索
  static String normalize(String text) {
    return text.replaceAllMapped(RegExp(r'\d+'), (match) {
      final numStr = match.group(0)!;
      final num = int.tryParse(numStr);
      if (num == null) return numStr;
      return _numberToChinese(num);
    });
  }

  static String _numberToChinese(int number) {
    if (number == 0) return _chineseNums[0];

    final StringBuffer buffer = StringBuffer();
    final String numStr = number.toString();

    // 简单处理 1-99
    if (number < 10) {
      return _chineseNums[number];
    } else if (number < 20) {
      if (number == 10) return '十';
      return '十${_chineseNums[number % 10]}';
    } else if (number < 100) {
      int ten = number ~/ 10;
      int unit = number % 10;
      return '${_chineseNums[ten]}十${unit == 0 ? "" : _chineseNums[unit]}';
    }

    // 对于更大数字，暂时直接返回原数字，或者按需扩展
    // 在经卷搜索场景中，卷数通常在100以内，或者几百，这里先简单支持到99
    // 如果需要支持更大数字，可以后续完善算法
    return number.toString();
  }

  /// 模糊匹配
  /// 1. 尝试直接匹配
  /// 2. 尝试将query中的数字转中文后匹配
  /// 3. 尝试子序列匹配 (query中的字符按顺序出现在text中)
  static bool fuzzyMatch(String text, String query) {
    if (query.isEmpty) return true;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // 1. 直接包含
    if (lowerText.contains(lowerQuery)) return true;

    // 2. 数字转换匹配 (例如 "31" -> "三十一")
    final normalizedQuery = normalize(lowerQuery);
    if (lowerText.contains(normalizedQuery)) return true;

    // 3. 混合转换匹配 (例如 "华严经31" -> "华严经三十一")
    // 这里处理的是 query 中部分是数字的情况
    if (normalizedQuery != lowerQuery && lowerText.contains(normalizedQuery)) {
      return true;
    }

    // 4. 子序列匹配 (宽松匹配)
    // 允许 "华严经31" 匹配 "大方广佛华严经...第三十一卷"
    // 我们使用 normalizedQuery 来做子序列匹配，因为 text 通常是中文
    return _isSubsequence(normalizedQuery, lowerText);
  }

  static bool _isSubsequence(String query, String text) {
    int i = 0; // query index
    int j = 0; // text index

    while (i < query.length && j < text.length) {
      if (query[i] == text[j]) {
        i++;
      }
      j++;
    }

    return i == query.length;
  }
}
