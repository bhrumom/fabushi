import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_service.dart';

class LocalProject {
  final String name;
  final String path;
  final DateTime updatedAt;
  final bool isExternal;

  const LocalProject({
    required this.name,
    required this.path,
    required this.updatedAt,
    this.isExternal = false,
  });
}

class ProjectService {
  ProjectService._();
  static final ProjectService instance = ProjectService._();
  static const String _externalProjectPathsKey =
      'desktop_external_project_paths_v1';

  Future<List<LocalProject>> listProjects() async {
    final projectsPath = await WorkspaceService.instance.getProjectsPath();
    final dir = Directory(projectsPath);
    final projects = <LocalProject>[];

    if (await dir.exists()) {
      for (final item in dir.listSync()) {
        if (item is Directory) {
          final stat = item.statSync();
          projects.add(
            LocalProject(
              name: p.basename(item.path),
              path: item.path,
              updatedAt: stat.modified,
            ),
          );
        }
      }
    }

    for (final path in await _loadExternalProjectPaths()) {
      final externalDir = Directory(path);
      if (!await externalDir.exists()) continue;
      final stat = await externalDir.stat();
      projects.add(
        LocalProject(
          name: p.basename(path),
          path: path,
          updatedAt: stat.modified,
          isExternal: true,
        ),
      );
    }

    final deduped = <String, LocalProject>{};
    for (final project in projects) {
      deduped[p.normalize(project.path)] = project;
    }

    return deduped.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<LocalProject> createProject(String name) async {
    final newPath = await _uniqueProjectPath(name);
    final dir = Directory(newPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return LocalProject(
      name: p.basename(dir.path),
      path: dir.path,
      updatedAt: DateTime.now(),
    );
  }

  Future<LocalProject> addProjectFromFolder(String folderPath) async {
    final normalized = p.normalize(folderPath.trim());
    if (normalized.isEmpty || !await Directory(normalized).exists()) {
      throw StateError('文件夹不存在');
    }

    final paths = await _loadExternalProjectPaths();
    if (!paths.contains(normalized)) {
      paths.add(normalized);
      await _saveExternalProjectPaths(paths);
    }

    final stat = await Directory(normalized).stat();
    return LocalProject(
      name: p.basename(normalized),
      path: normalized,
      updatedAt: stat.modified,
      isExternal: true,
    );
  }

  Future<void> deleteProject(String name) async {
    final projects = await listProjects();
    LocalProject? project;
    for (final item in projects) {
      if (item.name == name || item.path == name) {
        project = item;
        break;
      }
    }
    if (project == null) return;

    if (project.isExternal) {
      await _removeExternalProject(project.path);
      return;
    }

    final dir = Directory(project.path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<List<String>> _loadExternalProjectPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(_externalProjectPathsKey) ?? const [];
    return paths
        .map((path) => p.normalize(path.trim()))
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveExternalProjectPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_externalProjectPathsKey, paths.toSet().toList());
  }

  Future<void> _removeExternalProject(String folderPath) async {
    final normalized = p.normalize(folderPath.trim());
    final paths = await _loadExternalProjectPaths();
    if (paths.remove(normalized)) {
      await _saveExternalProjectPaths(paths);
    }
  }

  String _sanitizeProjectName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '未命名项目';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  Future<String> _uniqueProjectPath(String baseName) async {
    final projectsPath = await WorkspaceService.instance.getProjectsPath();
    final safeName = _sanitizeProjectName(baseName);
    var candidate = p.join(projectsPath, safeName);
    var index = 2;
    while (await Directory(candidate).exists()) {
      candidate = p.join(projectsPath, '$safeName $index');
      index += 1;
    }
    return candidate;
  }
}
