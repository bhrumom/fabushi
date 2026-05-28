import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
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
  static PracticeBookService? _instance;
  static PracticeBookService get instance =>
      _instance ??= PracticeBookService._();
  PracticeBookService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final dbFile = path.join(dbPath, 'practice_books.db');
    _database = await openDatabase(
      dbFile,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE practice_books (
            id TEXT PRIMARY KEY,
            practice_title TEXT NOT NULL,
            title TEXT NOT NULL,
            source_type TEXT NOT NULL,
            source_url TEXT,
            source_file_name TEXT,
            source_file_path TEXT,
            content_hash TEXT NOT NULL,
            plain_text TEXT NOT NULL,
            normalized_text TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            remote_object_key TEXT,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_practice_books_practice_title ON practice_books(practice_title)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE practice_books ADD COLUMN source_file_path TEXT',
          );
        }
      },
    );
    return _database!;
  }

  Future<List<PracticeBook>> listBooks({String? practiceTitle}) async {
    final db = await database;
    final maps = await db.query(
      'practice_books',
      where: practiceTitle == null ? null : 'practice_title = ?',
      whereArgs: practiceTitle == null ? null : [practiceTitle],
      orderBy: 'updated_at DESC',
    );
    return maps.map(PracticeBook.fromMap).toList();
  }

  Future<PracticeBook?> getActiveBook(String practiceTitle) async {
    final db = await database;
    final maps = await db.query(
      'practice_books',
      where: 'practice_title = ? AND is_active = 1',
      whereArgs: [practiceTitle],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PracticeBook.fromMap(maps.first);
  }

  Future<PracticeBook> saveBook(
    PracticeBook book, {
    bool syncCloud = false,
  }) async {
    final db = await database;
    final localBook = book.copyWith(
      isActive: true,
      syncStatus: PracticeBookSyncStatus.localOnly,
      remoteObjectKey: null,
    );
    await db.update(
      'practice_books',
      {'is_active': 0},
      where: 'practice_title = ?',
      whereArgs: [localBook.practiceTitle],
    );
    await db.insert(
      'practice_books',
      localBook.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return localBook;
  }

  Future<void> deleteBook(String id, {bool syncCloud = false}) async {
    final db = await database;
    await db.delete('practice_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<PracticeBookImportResult> importFile({
    required PlatformFile file,
    required String practiceTitle,
  }) async {
    try {
      final extension = path.extension(file.name).toLowerCase();
      if (_isImageExtension(extension)) {
        final book = await _importImage(
          file: file,
          practiceTitle: practiceTitle,
        );
        return PracticeBookImportResult.success(book);
      }

      final bytes = await _readPlatformFile(file);
      final plainText = switch (extension) {
        '.txt' || '.md' => _decodeTextBytes(bytes),
        '.docx' => _extractDocxText(bytes),
        '.pdf' => _extractPdfText(bytes),
        _ => throw UnsupportedError('暂不支持 $extension 文件'),
      };
      final normalizedPlainText = PracticeBookText.normalizePlainText(
        plainText,
      );
      if (normalizedPlainText.length < 2) {
        return const PracticeBookImportResult.failure('未能提取到可用正文');
      }

      final title = PracticeBookText.titleFromText(
        normalizedPlainText,
        fallback: path.basenameWithoutExtension(file.name),
      );
      final book = PracticeBook.create(
        id: const Uuid().v4(),
        practiceTitle: practiceTitle,
        title: title,
        sourceType: PracticeBookSourceType.file,
        sourceFileName: file.name,
        plainText: normalizedPlainText,
        syncStatus: PracticeBookSyncStatus.localOnly,
      );
      return PracticeBookImportResult.success(await saveBook(book));
    } catch (e) {
      return PracticeBookImportResult.failure('导入文件失败: $e');
    }
  }

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
      title: _titleFromUrl(uri),
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

  Future<void> syncFromCloud() async {
    debugPrint('[PracticeBook] Cloud sync disabled; books stay local only.');
  }

  Future<PracticeBook> _importImage({
    required PlatformFile file,
    required String practiceTitle,
  }) async {
    final bytes = await _readPlatformFile(file);
    final id = const Uuid().v4();
    final imageFile = await _copyImageToLocalStore(id, file.name, bytes);
    final title = path.basenameWithoutExtension(file.name).trim().isEmpty
        ? '图片功课本'
        : path.basenameWithoutExtension(file.name).trim();
    final book = PracticeBook.create(
      id: id,
      practiceTitle: practiceTitle,
      title: title,
      sourceType: PracticeBookSourceType.image,
      sourceFileName: file.name,
      sourceFilePath: imageFile.path,
      plainText: title,
      syncStatus: PracticeBookSyncStatus.localOnly,
    );
    return saveBook(book);
  }

  Future<File> _copyImageToLocalStore(
    String id,
    String originalName,
    List<int> bytes,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(path.join(dir.path, 'practice_books', 'images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final extension = path.extension(originalName).toLowerCase();
    final file = File(path.join(imageDir.path, '$id$extension'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<List<int>> _readPlatformFile(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      throw StateError('无法读取文件内容');
    }
    return await File(filePath).readAsBytes();
  }

  String _decodeTextBytes(List<int> bytes) {
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final replacementCount = '�'.allMatches(utf8Text).length;
    if (replacementCount < 4) return utf8Text;
    return gbk.decode(bytes);
  }

  String _extractDocxText(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');
    if (document == null) {
      throw StateError('DOCX 缺少正文');
    }
    final xml = utf8.decode(
      document.content as List<int>,
      allowMalformed: true,
    );
    return xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  String _extractPdfText(List<int> bytes) {
    final raw = latin1.decode(bytes);
    final matches = RegExp(r'\(([^()]{2,})\)\s*Tj').allMatches(raw);
    final text = matches
        .map((match) => match.group(1) ?? '')
        .join('\n')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')');
    if (text.trim().isNotEmpty) return text;

    final fallback = utf8.decode(bytes, allowMalformed: true);
    return fallback.replaceAll(
      RegExp(r'[^\u4e00-\u9fffA-Za-z0-9，。！？；：、\n ]'),
      ' ',
    );
  }

  bool _isImageExtension(String extension) {
    return const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(extension);
  }

  String _titleFromUrl(Uri uri) {
    final lastSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.trim()
        : '';
    if (lastSegment.isNotEmpty) {
      return Uri.decodeComponent(
        lastSegment,
      ).replaceAll(RegExp(r'\.[^.]+$'), '');
    }
    return uri.host.isEmpty ? '链接功课本' : uri.host;
  }
}
