import 'package:file_picker/file_picker.dart';

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
  static PracticeBookService? _instance;
  static PracticeBookService get instance =>
      _instance ??= PracticeBookService._();
  PracticeBookService._();

  Future<List<PracticeBook>> listBooks({String? practiceTitle}) async => [];
  Future<PracticeBook?> getActiveBook(String practiceTitle) async => null;
  Future<PracticeBook> saveBook(
    PracticeBook book, {
    bool syncCloud = false,
  }) async => book.copyWith(syncStatus: PracticeBookSyncStatus.localOnly);

  Future<void> deleteBook(String id, {bool syncCloud = false}) async {}

  Future<PracticeBookImportResult> importFile({
    required PlatformFile file,
    required String practiceTitle,
  }) async => const PracticeBookImportResult.failure('Web 暂不支持功课本文件导入');

  Future<PracticeBookImportResult> importUrl({
    required String url,
    required String practiceTitle,
  }) async => const PracticeBookImportResult.failure('Web 暂不支持功课本链接导入');

  Future<PracticeBook> saveManualText({
    required String practiceTitle,
    required String title,
    required String plainText,
  }) async {
    throw UnsupportedError('Web 暂不支持功课本保存');
  }

  Future<PracticeBook> saveExtractedWebText({
    required String practiceTitle,
    required String sourceUrl,
    required String title,
    required String plainText,
  }) async {
    throw UnsupportedError('Web 暂不支持功课本保存');
  }

  Future<void> syncFromCloud() async {}
}
