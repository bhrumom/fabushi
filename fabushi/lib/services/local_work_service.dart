import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/local_work_model.dart';

class LocalWorkService {
  static LocalWorkService? _instance;
  static LocalWorkService get instance => _instance ??= LocalWorkService._();

  LocalWorkService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('local_works.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE works (
        id TEXT PRIMARY KEY,
        content_id TEXT NOT NULL,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        cover_url TEXT
      )
    ''');
  }

  Future<void> saveWork(LocalWorkModel work) async {
    final db = await database;
    await db.insert(
      'works',
      work.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[LocalWorkService] Saved work: ${work.title}');
  }

  Future<List<LocalWorkModel>> getWorks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'works',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return LocalWorkModel.fromMap(maps[i]);
    });
  }

  Future<void> deleteWork(String id) async {
    final db = await database;
    await db.delete('works', where: 'id = ?', whereArgs: [id]);
    debugPrint('[LocalWorkService] Deleted work: $id');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
