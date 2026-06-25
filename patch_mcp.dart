import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() async {
  final file = File('/Users/gloriachan/Documents/fabushi/fabushi/lib/services/openclaw/openclaw_runtime_io.dart');
  var content = await file.readAsString();
  if (!content.contains('mcp_config.json')) {
    final mcpLogic = '''
    // Load MCP config if it exists
    final mcpConfigPath = File(p.join(Platform.environment['HOME'] ?? '', '.gemini', 'config', 'mcp_config.json'));
    if (await mcpConfigPath.exists()) {
      try {
        final mcpConfig = jsonDecode(await mcpConfigPath.readAsString());
        if (mcpConfig is Map && mcpConfig.containsKey('mcpServers')) {
          config['mcpServers'] = mcpConfig['mcpServers'];
        }
      } catch (e) {
        _diag('mcp.config-error', data: {'error': e.toString()});
      }
    }
''';
    content = content.replaceFirst(
      'final merged = await _mergeEmbeddedConfig(configPath, config);',
      mcpLogic + '\n    final merged = await _mergeEmbeddedConfig(configPath, config);'
    );
    await file.writeAsString(content);
    print('Patched successfully');
  } else {
    print('Already patched');
  }
}
