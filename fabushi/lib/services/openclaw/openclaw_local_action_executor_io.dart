import 'dart:io';

import 'package:path/path.dart' as p;

class OpenClawLocalActionResult {
  final String message;
  final Map<String, dynamic> raw;

  const OpenClawLocalActionResult({required this.message, this.raw = const {}});
}

class OpenClawLocalActionExecutor {
  OpenClawLocalActionExecutor._();

  static final OpenClawLocalActionExecutor instance =
      OpenClawLocalActionExecutor._();

  Future<OpenClawLocalActionResult?> tryExecute({
    required String message,
    Map<String, dynamic>? client,
  }) async {
    final text = message.trim();
    if (text.isEmpty || !_isCreateFolderIntent(text)) return null;

    final project = _selectedProject(client);
    final projectPath = project['path']?.toString().trim() ?? '';
    if (projectPath.isEmpty) return null;

    final parent = Directory(p.normalize(projectPath));
    if (!await parent.exists()) {
      return OpenClawLocalActionResult(
        message: '当前选择的项目文件夹不存在，未能创建文件夹。\n\n路径：${parent.path}',
        raw: {
          'type': 'local.create_folder',
          'success': false,
          'reason': 'project_not_found',
          'projectPath': parent.path,
        },
      );
    }

    final folderName = _folderNameFromMessage(text);
    final targetPath = await _uniqueChildDirectoryPath(parent.path, folderName);
    final target = Directory(targetPath);
    await target.create(recursive: true);

    final projectName = project['name']?.toString().trim();
    final displayProject = projectName == null || projectName.isEmpty
        ? p.basename(parent.path)
        : projectName;
    final relativePath = p.relative(target.path, from: parent.path);

    return OpenClawLocalActionResult(
      message: '已在项目「$displayProject」里创建文件夹：$relativePath\n\n路径：${target.path}',
      raw: {
        'type': 'local.create_folder',
        'success': true,
        'projectName': displayProject,
        'projectPath': parent.path,
        'folderName': p.basename(target.path),
        'path': target.path,
      },
    );
  }

  Map<String, dynamic> _selectedProject(Map<String, dynamic>? client) {
    if (client == null) return const {};
    final rawProject = client['project'];
    if (rawProject is Map<String, dynamic>) return rawProject;
    if (rawProject is Map) return Map<String, dynamic>.from(rawProject);
    return const {};
  }

  bool _isCreateFolderIntent(String text) {
    final lower = text.toLowerCase();
    final hasFolder = RegExp(
      r'(folder|directory|文件夹|目录)',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!hasFolder) return false;
    return RegExp(
      r'(create|make|mkdir|new|add|创建|新建|建立|添加)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  String _folderNameFromMessage(String text) {
    final quoted = RegExp(r'["“”「」『』《》](.+?)["“”「」『』《》]').firstMatch(text);
    if (quoted != null) {
      final candidate = _cleanFolderNameCandidate(
        quoted.group(1)?.trim() ?? '',
      );
      if (candidate.isNotEmpty) return _sanitizeFolderName(candidate);
    }

    final named = RegExp(
      r'(?:名为|命名为|名字叫|叫做|叫|名称是|named|called)\s*([^\s，。,.；;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (named != null) {
      final candidate = _cleanFolderNameCandidate(named.group(1)?.trim() ?? '');
      if (candidate.isNotEmpty) return _sanitizeFolderName(candidate);
    }

    return '新建文件夹';
  }

  String _cleanFolderNameCandidate(String value) {
    return value
        .replaceFirst(RegExp(r'(的)?(文件夹|目录|folder|directory)$'), '')
        .trim();
  }

  String _sanitizeFolderName(String name) {
    final trimmed = name.trim();
    final safe = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return '新建文件夹';
    return safe.length > 80 ? safe.substring(0, 80).trim() : safe;
  }

  Future<String> _uniqueChildDirectoryPath(
    String parentPath,
    String folderName,
  ) async {
    final baseName = _sanitizeFolderName(folderName);
    var candidate = p.join(parentPath, baseName);
    var suffix = 2;
    while (await Directory(candidate).exists()) {
      candidate = p.join(parentPath, '$baseName $suffix');
      suffix += 1;
    }
    return candidate;
  }
}
