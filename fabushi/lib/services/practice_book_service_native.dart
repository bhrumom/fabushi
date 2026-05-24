import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../models/practice_book_model.dart';
import 'app_settings.dart';

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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE practice_books (
            id TEXT PRIMARY KEY,
            practice_title TEXT NOT NULL,
            title TEXT NOT NULL,
            source_type TEXT NOT NULL,
            source_url TEXT,
            source_file_name TEXT,
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
    bool syncCloud = true,
  }) async {
    final db = await database;
    await db.update(
      'practice_books',
      {'is_active': 0},
      where: 'practice_title = ?',
      whereArgs: [book.practiceTitle],
    );
    await db.insert(
      'practice_books',
      book.copyWith(isActive: true).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (syncCloud) {
      return await _uploadBookToCloud(book.copyWith(isActive: true));
    }
    return book.copyWith(isActive: true);
  }

  Future<void> deleteBook(String id, {bool syncCloud = true}) async {
    final db = await database;
    await db.delete('practice_books', where: 'id = ?', whereArgs: [id]);

    if (!syncCloud) return;
    final headers = await _authHeaders();
    if (headers == null) return;
    try {
      final baseUrl = await AppSettings.getBackendUrl();
      await http.delete(
        Uri.parse(
          '$baseUrl/api/meditation/practice-books',
        ).replace(queryParameters: {'id': id}),
        headers: headers,
      );
    } catch (e) {
      debugPrint('[PracticeBook] 云端删除失败: $e');
    }
  }

  Future<PracticeBookImportResult> importFile({
    required PlatformFile file,
    required String practiceTitle,
  }) async {
    try {
      final bytes = await _readPlatformFile(file);
      final extension = path.extension(file.name).toLowerCase();
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
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      return const PracticeBookImportResult.failure('请输入 http/https 链接');
    }

    final headers = await _authHeaders();
    if (headers == null) {
      return const PracticeBookImportResult.failure('请先登录后再同步链接功课本');
    }

    try {
      final baseUrl = await AppSettings.getBackendUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/api/meditation/practice-books/import-url'),
        headers: headers,
        body: jsonEncode({
          'url': normalizedUrl,
          'practiceTitle': practiceTitle,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        final needsFallback =
            data['needsWebViewFallback'] == true ||
            normalizedUrl.contains('mp.weixin.qq.com');
        return PracticeBookImportResult.failure(
          data['error']?.toString() ?? '链接解析失败',
          needsWebViewFallback: needsFallback,
        );
      }

      final book = PracticeBook.fromJson(
        Map<String, dynamic>.from(data['data']['book'] as Map),
      ).copyWith(syncStatus: PracticeBookSyncStatus.synced, isActive: true);
      await saveBook(book, syncCloud: false);
      return PracticeBookImportResult.success(book);
    } catch (e) {
      return PracticeBookImportResult.failure(
        '链接解析失败: $e',
        needsWebViewFallback: normalizedUrl.contains('mp.weixin.qq.com'),
      );
    }
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
    );
    return await saveBook(book);
  }

  Future<void> syncFromCloud() async {
    final headers = await _authHeaders();
    if (headers == null) return;
    try {
      final baseUrl = await AppSettings.getBackendUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/api/meditation/practice-books'),
        headers: headers,
      );
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data['success'] != true) return;
      final books = (data['data']?['books'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                PracticeBook.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      for (final book in books) {
        await saveBook(
          book.copyWith(syncStatus: PracticeBookSyncStatus.synced),
          syncCloud: false,
        );
      }
    } catch (e) {
      debugPrint('[PracticeBook] 云端同步失败: $e');
    }
  }

  Future<PracticeBook> _uploadBookToCloud(PracticeBook book) async {
    final headers = await _authHeaders();
    if (headers == null) {
      final pending = book.copyWith(
        syncStatus: PracticeBookSyncStatus.pendingUpload,
      );
      await _saveLocalOnly(pending);
      return pending;
    }

    try {
      final baseUrl = await AppSettings.getBackendUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/api/meditation/practice-books'),
        headers: headers,
        body: jsonEncode(book.toJson()),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']?['book'] is Map) {
          final synced = PracticeBook.fromJson(
            Map<String, dynamic>.from(data['data']['book'] as Map),
          ).copyWith(syncStatus: PracticeBookSyncStatus.synced);
          await _saveLocalOnly(synced);
          return synced;
        }
      }
    } catch (e) {
      debugPrint('[PracticeBook] 云端上传失败: $e');
    }

    final failed = book.copyWith(syncStatus: PracticeBookSyncStatus.syncFailed);
    await _saveLocalOnly(failed);
    return failed;
  }

  Future<void> _saveLocalOnly(PracticeBook book) async {
    final db = await database;
    await db.insert(
      'practice_books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.tokenStorageKey);
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
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
    return fallback.replaceAll(RegExp(r'[^一-龥A-Za-z0-9，。！？；：、\n ]'), ' ');
  }
}
