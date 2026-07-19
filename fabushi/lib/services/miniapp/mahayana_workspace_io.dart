import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Map<String, dynamic>>? _preparedPaths;

Future<Map<String, dynamic>> prepareMahayanaRuntimePaths() {
  return _preparedPaths ??= _createRuntimePaths();
}

Future<Map<String, dynamic>> _createRuntimePaths() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'mahayana-runtime'));
  final workspace = Directory(p.join(root.path, 'workspace'));
  final codexHome = Directory(p.join(root.path, 'codex'));
  await Future.wait([
    root.create(recursive: true),
    workspace.create(recursive: true),
    codexHome.create(recursive: true),
  ]);
  final bundledPluginMarketplace = _findBundledPluginMarketplace();
  return <String, dynamic>{
    'dataDir': root.path,
    'workspaceRoots': <String>[workspace.path],
    'cwd': workspace.path,
    'codexHome': codexHome.path,
    if (bundledPluginMarketplace != null)
      'bundledPluginMarketplace': bundledPluginMarketplace.path,
  };
}

Directory? _findBundledPluginMarketplace() {
  final executableDirectory = File(Platform.resolvedExecutable).parent;
  final candidates = <Directory>[
    Directory(p.join(executableDirectory.path, 'share', 'mahayana', 'plugins')),
    Directory(
      p.join(
        executableDirectory.parent.path,
        'Resources',
        'mahayana',
        'share',
        'mahayana',
        'plugins',
      ),
    ),
  ];
  for (final candidate in candidates) {
    if (File(p.join(candidate.path, 'marketplace.json')).existsSync()) {
      return candidate;
    }
  }
  return null;
}

Future<String?> readMahayanaWorkspaceFile(String relativePath) async {
  final file = await _workspaceFile(relativePath);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> clearMahayanaWorkspaceFile(String relativePath) async {
  final file = await _workspaceFile(relativePath);
  if (await file.exists()) await file.delete();
}

Future<File> _workspaceFile(String relativePath) async {
  final normalized = p.normalize(relativePath.trim());
  if (normalized.isEmpty ||
      p.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    throw ArgumentError.value(relativePath, 'relativePath', 'unsafe path');
  }
  final paths = await prepareMahayanaRuntimePaths();
  final roots = paths['workspaceRoots'] as List<String>?;
  if (roots == null || roots.isEmpty) {
    throw StateError('Mahayana workspace is unavailable on this platform.');
  }
  final root = p.normalize(roots.first);
  final candidate = p.normalize(p.join(root, normalized));
  if (candidate != root && !p.isWithin(root, candidate)) {
    throw ArgumentError.value(relativePath, 'relativePath', 'unsafe path');
  }
  return File(candidate);
}
