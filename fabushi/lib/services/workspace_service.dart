import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// WorkspaceService manages the local physical file paths for projects and chats
class WorkspaceService {
  WorkspaceService._();
  static final WorkspaceService instance = WorkspaceService._();

  String? _basePath;

  /// Returns the root `~/Documents/fabushi` path
  Future<String> getBasePath() async {
    if (_basePath != null) return _basePath!;
    
    // Fallback if path_provider fails or not supported (e.g. web)
    if (kIsWeb) {
      _basePath = '/mock_web_storage/fabushi';
      return _basePath!;
    }
    
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final String rootDir = p.join(docsDir.path, 'fabushi');
    
    final dir = Directory(rootDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    _basePath = rootDir;
    return rootDir;
  }

  /// Returns `~/Documents/fabushi/projects`
  Future<String> getProjectsPath() async {
    final root = await getBasePath();
    final path = p.join(root, 'projects');
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  /// Returns `~/Documents/fabushi/chats`
  Future<String> getChatsPath() async {
    final root = await getBasePath();
    final path = p.join(root, 'chats');
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  /// Returns `~/Documents/fabushi/chats/YYYY-MM-DD`
  Future<String> getDailyChatsPath([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    final dateString = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    
    final chatsRoot = await getChatsPath();
    final path = p.join(chatsRoot, dateString);
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }
}
