import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'miniapp/mahayana_workspace.dart';

const _maxFilesPerPlugin = 400;
const _maxUiBytes = 2 * 1024 * 1024;

Future<List<Map<String, dynamic>>>? _cachedDiscovery;

Future<List<Map<String, dynamic>>> discoverCodexPlugins({
  bool forceRefresh = false,
}) {
  if (forceRefresh) _cachedDiscovery = null;
  return _cachedDiscovery ??= _discover();
}

Future<List<Map<String, dynamic>>> _discover() async {
  final roots = await _pluginRoots();
  final plugins = <String, Map<String, dynamic>>{};
  for (final root in roots) {
    final descriptor = await _readPlugin(root);
    if (descriptor == null) continue;
    final id = descriptor['id']!.toString();
    final existing = plugins[id];
    if (existing == null ||
        _descriptorScore(descriptor) > _descriptorScore(existing)) {
      plugins[id] = descriptor;
    }
  }
  final result = plugins.values.toList(growable: false)
    ..sort((left, right) {
      return left['title'].toString().toLowerCase().compareTo(
        right['title'].toString().toLowerCase(),
      );
    });
  return result;
}

int _descriptorScore(Map<String, dynamic> descriptor) {
  var score = descriptor['uiHtml'] == null ? 0 : 4;
  final root = descriptor['rootPath']?.toString() ?? '';
  if (root.contains('${p.separator}share${p.separator}mahayana')) score += 2;
  if ((descriptor['files'] as List? ?? const []).isNotEmpty) score += 1;
  return score;
}

Future<List<Directory>> _pluginRoots() async {
  final roots = <String, Directory>{};
  final runtimePaths = await prepareMahayanaRuntimePaths();
  final bundledPath = runtimePaths['bundledPluginMarketplace']?.toString();
  if (bundledPath != null && bundledPath.isNotEmpty) {
    await _addMarketplacePlugins(Directory(bundledPath), roots);
  }

  final codexHome = runtimePaths['codexHome']?.toString();
  if (codexHome != null && codexHome.isNotEmpty) {
    await _addManifestParents(
      Directory(p.join(codexHome, 'plugins')),
      roots,
      maxDepth: 8,
    );
  }

  final configuredCodexHome = Platform.environment['CODEX_HOME']?.trim();
  final userHome = (Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'])
      ?.trim();
  final desktopCodexHome = configuredCodexHome?.isNotEmpty == true
      ? configuredCodexHome
      : userHome?.isNotEmpty == true
      ? p.join(userHome!, '.codex')
      : null;
  if (desktopCodexHome != null &&
      p.canonicalize(desktopCodexHome) != p.canonicalize(codexHome ?? '')) {
    await _addManifestParents(
      Directory(p.join(desktopCodexHome, 'plugins')),
      roots,
      maxDepth: 10,
    );
  }

  var cursor = Directory.current.absolute;
  for (var depth = 0; depth < 7; depth++) {
    final developerMarketplace = Directory(
      p.join(cursor.path, '.agents', 'plugins'),
    );
    if (await File(
      p.join(developerMarketplace.path, 'marketplace.json'),
    ).exists()) {
      await _addMarketplacePlugins(developerMarketplace, roots);
      break;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  return roots.values.toList(growable: false);
}

Future<void> _addMarketplacePlugins(
  Directory marketplace,
  Map<String, Directory> roots,
) async {
  final manifestFile = File(p.join(marketplace.path, 'marketplace.json'));
  try {
    final decoded = jsonDecode(await manifestFile.readAsString());
    final plugins = decoded is Map ? decoded['plugins'] as List? : null;
    for (final item in plugins ?? const []) {
      if (item is! Map) continue;
      final source = item['source'];
      final relativePath = source is Map ? source['path']?.toString() : null;
      if (relativePath == null || relativePath.trim().isEmpty) continue;
      final candidate = Directory(
        p.normalize(p.join(marketplace.path, relativePath)),
      );
      if (await _hasPluginManifest(candidate)) {
        roots[p.canonicalize(candidate.path)] = candidate;
      }
    }
  } catch (_) {
    final pluginsDirectory = Directory(p.join(marketplace.path, 'plugins'));
    if (!await pluginsDirectory.exists()) return;
    await for (final entity in pluginsDirectory.list(followLinks: false)) {
      if (entity is Directory && await _hasPluginManifest(entity)) {
        roots[p.canonicalize(entity.path)] = entity;
      }
    }
  }
}

Future<void> _addManifestParents(
  Directory directory,
  Map<String, Directory> roots, {
  required int maxDepth,
}) async {
  if (!await directory.exists()) return;
  final baseDepth = p.split(p.normalize(directory.absolute.path)).length;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    final depth = p.split(p.normalize(entity.absolute.path)).length - baseDepth;
    if (depth > maxDepth) continue;
    if (entity is! File || p.basename(entity.path) != 'plugin.json') continue;
    if (p.basename(p.dirname(entity.path)) != '.codex-plugin') continue;
    final root = Directory(p.dirname(p.dirname(entity.path)));
    roots[p.canonicalize(root.path)] = root;
  }
}

Future<bool> _hasPluginManifest(Directory root) {
  return File(p.join(root.path, '.codex-plugin', 'plugin.json')).exists();
}

Future<Map<String, dynamic>?> _readPlugin(Directory root) async {
  final manifestFile = File(p.join(root.path, '.codex-plugin', 'plugin.json'));
  try {
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) return null;
    final manifest = Map<String, dynamic>.from(decoded);
    final id = manifest['name']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final interface = manifest['interface'] is Map
        ? Map<String, dynamic>.from(manifest['interface'] as Map)
        : const <String, dynamic>{};
    final title = interface['displayName']?.toString().trim();
    final shortDescription = interface['shortDescription']?.toString().trim();
    final uiEntry = await _findUiEntry(root, manifest);
    final uiHtml = uiEntry == null ? null : await _readUi(uiEntry);
    return {
      'id': id,
      'title': title?.isNotEmpty == true ? title : id,
      'description': shortDescription?.isNotEmpty == true
          ? shortDescription
          : manifest['description']?.toString().trim() ?? '',
      'rootPath': root.absolute.path,
      'skills': await _skillNames(root, manifest),
      'mcpServers': await _mcpServerNames(root, manifest),
      'files': await _fileEntries(root),
      if (uiEntry != null)
        'uiEntryPath': p.relative(uiEntry.path, from: root.path),
      'uiHtml': ?uiHtml,
    };
  } catch (_) {
    return null;
  }
}

Future<File?> _findUiEntry(
  Directory root,
  Map<String, dynamic> manifest,
) async {
  final declared = <String>[];
  final ui = manifest['ui'];
  if (ui is String) {
    declared.add(ui);
  } else if (ui is Map) {
    for (final key in const ['entry', 'path', 'home', 'index']) {
      final value = ui[key]?.toString().trim();
      if (value?.isNotEmpty == true) declared.add(value!);
    }
  }
  final candidates = [
    ...declared,
    'ui/home.html',
    'ui/index.html',
    'app/index.html',
    'dist/index.html',
  ];
  for (final relativePath in candidates) {
    final normalized = p.normalize(
      relativePath.replaceFirst(RegExp(r'^\./'), ''),
    );
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) continue;
    final file = File(p.join(root.path, normalized));
    if (await file.exists() && await file.length() <= _maxUiBytes) return file;
  }
  return null;
}

Future<String?> _readUi(File file) async {
  try {
    if (await file.length() > _maxUiBytes) return null;
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}

Future<List<String>> _skillNames(
  Directory root,
  Map<String, dynamic> manifest,
) async {
  final names = <String>{};
  final declared = manifest['skills'];
  if (declared is List) {
    for (final value in declared) {
      final path = value is Map ? value['path']?.toString() : value.toString();
      if (path == null || path.trim().isEmpty) continue;
      final normalized = p.normalize(path.replaceFirst(RegExp(r'^\./'), ''));
      final name = p.basename(normalized) == 'SKILL.md'
          ? p.basename(p.dirname(normalized))
          : p.basename(normalized);
      if (name.isNotEmpty) names.add(name);
    }
  }
  final skillsRoot = Directory(p.join(root.path, 'skills'));
  if (await skillsRoot.exists()) {
    await for (final entity in skillsRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && p.basename(entity.path) == 'SKILL.md') {
        names.add(p.basename(p.dirname(entity.path)));
      }
    }
  }
  final result = names.toList(growable: false)..sort();
  return result;
}

Future<List<String>> _mcpServerNames(
  Directory root,
  Map<String, dynamic> manifest,
) async {
  final names = <String>{};
  names.addAll(
    await _declaredMapKeys(root, manifest['mcpServers'], 'mcpServers'),
  );
  names.addAll(await _declaredMapKeys(root, manifest['apps'], 'apps'));
  final result = names.toList(growable: false)..sort();
  return result;
}

Future<List<String>> _declaredMapKeys(
  Directory root,
  Object? declaration,
  String containerKey,
) async {
  if (declaration is Map) {
    return declaration.keys
        .map((key) => key.toString())
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
  }
  if (declaration is! String || declaration.trim().isEmpty) return const [];
  final normalized = p.normalize(declaration.replaceFirst(RegExp(r'^\./'), ''));
  if (p.isAbsolute(normalized) || normalized.startsWith('..')) return const [];
  try {
    final decoded = jsonDecode(
      await File(p.join(root.path, normalized)).readAsString(),
    );
    final entries = decoded is Map ? decoded[containerKey] : null;
    if (entries is! Map) return const [];
    return entries.keys
        .map((key) => key.toString())
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

Future<List<Map<String, dynamic>>> _fileEntries(Directory root) async {
  final entries = <Map<String, dynamic>>[];
  try {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entries.length >= _maxFilesPerPlugin) break;
      final relative = p.relative(entity.path, from: root.path);
      if (_isIgnored(relative)) continue;
      final isDirectory = entity is Directory;
      entries.add({
        'path': relative,
        'isDirectory': isDirectory,
        'size': isDirectory ? 0 : await (entity as File).length(),
      });
    }
  } catch (_) {
    // A partially readable plugin still gets a useful manifest-level entry.
  }
  entries.sort((left, right) {
    final leftDirectory = left['isDirectory'] == true;
    final rightDirectory = right['isDirectory'] == true;
    final leftPath = left['path']!.toString();
    final rightPath = right['path']!.toString();
    final leftParent = p.dirname(leftPath);
    final rightParent = p.dirname(rightPath);
    final parentOrder = leftParent.compareTo(rightParent);
    if (parentOrder != 0) return parentOrder;
    if (leftDirectory != rightDirectory) return leftDirectory ? -1 : 1;
    return leftPath.compareTo(rightPath);
  });
  return entries;
}

bool _isIgnored(String relativePath) {
  final segments = p.split(relativePath);
  return segments.any(
    (segment) => const {'.git', 'node_modules', 'target'}.contains(segment),
  );
}
