import 'codex_plugin_catalog_stub.dart'
    if (dart.library.io) 'codex_plugin_catalog_io.dart'
    as implementation;

class CodexPluginFileEntry {
  const CodexPluginFileEntry({
    required this.path,
    required this.isDirectory,
    required this.size,
  });

  final String path;
  final bool isDirectory;
  final int size;

  factory CodexPluginFileEntry.fromJson(Map<String, dynamic> json) {
    return CodexPluginFileEntry(
      path: json['path']?.toString() ?? '',
      isDirectory: json['isDirectory'] == true,
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class CodexPluginDescriptor {
  const CodexPluginDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.rootPath,
    required this.skills,
    required this.mcpServers,
    required this.files,
    this.uiEntryPath,
    this.uiHtml,
  });

  final String id;
  final String title;
  final String description;
  final String rootPath;
  final List<String> skills;
  final List<String> mcpServers;
  final List<CodexPluginFileEntry> files;
  final String? uiEntryPath;
  final String? uiHtml;

  bool get hasUi => uiEntryPath?.isNotEmpty == true && uiHtml != null;

  factory CodexPluginDescriptor.fromJson(Map<String, dynamic> json) {
    return CodexPluginDescriptor(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '',
      skills: _stringList(json['skills']),
      mcpServers: _stringList(json['mcpServers']),
      files: (json['files'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (entry) =>
                CodexPluginFileEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((entry) => entry.path.isNotEmpty)
          .toList(growable: false),
      uiEntryPath: _optionalString(json['uiEntryPath']),
      uiHtml: _optionalString(json['uiHtml']),
    );
  }
}

class CodexPluginCatalogService {
  CodexPluginCatalogService._();

  static final instance = CodexPluginCatalogService._();

  Future<List<CodexPluginDescriptor>> listPlugins({
    bool forceRefresh = false,
  }) async {
    final raw = await implementation.discoverCodexPlugins(
      forceRefresh: forceRefresh,
    );
    return raw
        .map(CodexPluginDescriptor.fromJson)
        .where((plugin) => plugin.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<CodexPluginDescriptor?> findPlugin(
    String pluginId, {
    bool forceRefresh = false,
  }) async {
    final normalized = _normalizePluginId(pluginId);
    final plugins = await listPlugins(forceRefresh: forceRefresh);
    for (final plugin in plugins) {
      if (_normalizePluginId(plugin.id) == normalized) return plugin;
    }
    return null;
  }
}

String normalizeCodexPluginId(String value) => _normalizePluginId(value);

String _normalizePluginId(String value) {
  return value.trim().replaceFirst(RegExp(r'^official\.'), '').split('@').first;
}

List<String> _stringList(Object? value) {
  return (value as List? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
