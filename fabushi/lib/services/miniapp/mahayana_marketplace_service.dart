import '../codex_plugin_catalog.dart';
import '../mahayana_sdk.dart';
import 'mahayana_workspace.dart';

/// Production marketplace operations for native Mahayana hosts.
///
/// This service deliberately delegates installation to Rust through the same
/// product FFI used by the shipped application. E2E tests must drive this
/// service through the UI; they must never pre-copy plugin files into the app
/// sandbox.
class MahayanaMarketplaceService {
  MahayanaMarketplaceService._();

  static final MahayanaMarketplaceService instance =
      MahayanaMarketplaceService._();

  Future<Map<String, dynamic>> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must not be empty');
    }
    return MahayanaSdk.instance.execute({
      '@type': 'mahayana.marketplace.search',
      'query': normalized,
      'platform': 'mobile',
    });
  }

  Future<Map<String, dynamic>> install(
    String pluginId, {
    String? version,
  }) async {
    final normalized = _pluginId(pluginId);
    final codexHome = await _codexHome();
    final response = await MahayanaSdk.instance.execute({
      '@type': 'mahayana.marketplace.install',
      'pluginId': normalized,
      'platform': 'mobile',
      'codexHome': codexHome,
      if (version?.trim().isNotEmpty == true) 'version': version!.trim(),
    });
    await CodexPluginCatalogService.instance.listPlugins(forceRefresh: true);
    return response;
  }

  Future<Map<String, dynamic>> inspect(String pluginId) async {
    final normalized = _pluginId(pluginId);
    return MahayanaSdk.instance.execute({
      '@type': 'mahayana.marketplace.inspect',
      'pluginId': normalized,
      'codexHome': await _codexHome(),
    });
  }

  Future<String> _codexHome() async {
    final paths = await prepareMahayanaRuntimePaths();
    final value = paths['codexHome']?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw StateError('Marketplace installation is unavailable on this platform.');
    }
    return value;
  }

  String _pluginId(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^official\.'), '');
    if (normalized.isEmpty ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized)) {
      throw ArgumentError.value(value, 'pluginId', 'invalid marketplace id');
    }
    return normalized;
  }
}
