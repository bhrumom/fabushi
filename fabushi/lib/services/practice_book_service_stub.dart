import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/practice_book_model.dart';

class PracticeBookImportResult {
  final PracticeBook? book;
  final String? error;
  final bool needsWebViewFallback;

  const PracticeBookImportResult.success(this.book)
    : error = null,
      needsWebViewFallback = false;

  const PracticeBookImportResult.failure(
    this.error, {
    this.needsWebViewFallback = false,
  }) : book = null;

  bool get isSuccess => book != null;
}

class PracticeBookService {
  static const String _prefsKey = 'practice_books_web_v1';

  static PracticeBookService? _instance;
  static PracticeBookService get instance =>
      _instance ??= PracticeBookService._();
  PracticeBookService._();

  Future<List<PracticeBook>> listBooks({String? practiceTitle}) async {
    final books = await _loadBooks();
    final filtered = practiceTitle == null
        ? books
        : books.where((book) => book.practiceTitle == practiceTitle).toList();
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  Future<PracticeBook?> getActiveBook(String practiceTitle) async {
    final books = await listBooks(practiceTitle: practiceTitle);
    for (final book in books) {
      if (book.isActive) return book;
    }
    return books.isEmpty ? null : books.first;
  }

  Future<PracticeBook> saveBook(
    PracticeBook book, {
    bool syncCloud = false,
  }) async {
    final books = await _loadBooks();
    final localBook = book.copyWith(
      isActive: true,
      syncStatus: PracticeBookSyncStatus.localOnly,
      remoteObjectKey: null,
    );
    final next = books
        .where((item) => item.id != localBook.id)
        .map(
          (item) => item.practiceTitle == localBook.practiceTitle
              ? item.copyWith(isActive: false)
              : item,
        )
        .toList();
    next.add(localBook);
    await _saveBooks(next);
    return localBook;
  }

  Future<void> deleteBook(String id, {bool syncCloud = false}) async {
    final books = await _loadBooks();
    await _saveBooks(books.where((book) => book.id != id).toList());
  }

  Future<PracticeBookImportResult> importFile({
    required PlatformFile file,
    required String practiceTitle,
  }) async => const PracticeBookImportResult.failure('Web 暂不支持功课本文件导入');

  Future<PracticeBookImportResult> importUrl({
    required String url,
    required String practiceTitle,
  }) async {
    final normalizedUrl = url.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return const PracticeBookImportResult.failure('请输入 http/https 链接');
    }
    final book = PracticeBook.create(
      id: const Uuid().v4(),
      practiceTitle: practiceTitle,
      title: uri.host,
      sourceType: PracticeBookSourceType.url,
      sourceUrl: normalizedUrl,
      plainText: normalizedUrl,
      syncStatus: PracticeBookSyncStatus.localOnly,
    );
    return PracticeBookImportResult.success(await saveBook(book));
  }

  Future<PracticeBook> saveManualText({
    required String practiceTitle,
    required String title,
    required String plainText,
  }) async {
    final normalizedPlainText = PracticeBookText.normalizePlainText(plainText);
    if (normalizedPlainText.length < 2) {
      throw ArgumentError('请输入功课文本内容');
    }
    final book = PracticeBook.create(
      id: const Uuid().v4(),
      practiceTitle: practiceTitle,
      title: title.trim().isEmpty
          ? PracticeBookText.titleFromText(normalizedPlainText)
          : title.trim(),
      sourceType: PracticeBookSourceType.manual,
      plainText: normalizedPlainText,
      syncStatus: PracticeBookSyncStatus.localOnly,
    );
    return saveBook(book);
  }

  Future<PracticeBook> saveExtractedWebText({
    required String practiceTitle,
    required String sourceUrl,
    required String title,
    required String plainText,
  }) async {
    final normalizedPlainText = PracticeBookText.normalizePlainText(plainText);
    if (normalizedPlainText.length < 2) {
      throw ArgumentError('未提取到可保存的功课正文');
    }
    final book = PracticeBook.create(
      id: const Uuid().v4(),
      practiceTitle: practiceTitle,
      title: title.trim().isEmpty
          ? PracticeBookText.titleFromText(normalizedPlainText)
          : title.trim(),
      sourceType: PracticeBookSourceType.url,
      sourceUrl: sourceUrl,
      plainText: normalizedPlainText,
      syncStatus: PracticeBookSyncStatus.localOnly,
    );
    return saveBook(book);
  }

  Future<void> syncFromCloud() async {}

  Future<List<PracticeBook>> _loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => PracticeBook.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveBooks(List<PracticeBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(books.map((book) => book.toJson()).toList()),
    );
  }
}
