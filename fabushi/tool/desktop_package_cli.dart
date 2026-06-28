import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

const String appExecutableName = 'global_dharma_sharing';
const String cliExecutableName = 'global_dharma_sharing_cli';

Future<void> main(List<String> args) async {
  final cli = DesktopSmokeCli(args);
  try {
    exitCode = await cli.run();
    return;
  } on CliFailure catch (error) {
    if (cli.jsonOutput) {
      cli.writeJson({
        'ok': false,
        'command': cli.command,
        'error': error.message,
        'checks': cli.checks.map((item) => item.toJson()).toList(),
      });
    } else {
      stderr.writeln('ERROR: ${error.message}');
      if (cli.checks.isNotEmpty) {
        stderr.writeln('Checks:');
        for (final check in cli.checks) {
          stderr.writeln(
            '  ${check.ok ? 'ok' : 'fail'} ${check.name}: ${check.message}',
          );
        }
      }
    }
    exitCode = error.exitCode;
    return;
  } catch (error, stackTrace) {
    if (cli.jsonOutput) {
      cli.writeJson({
        'ok': false,
        'command': cli.command,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'checks': cli.checks.map((item) => item.toJson()).toList(),
      });
    } else {
      stderr.writeln('ERROR: $error');
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

class DesktopSmokeCli {
  DesktopSmokeCli(this.args);

  final List<String> args;
  final List<SmokeCheck> checks = <SmokeCheck>[];

  String command = 'doctor';
  bool jsonOutput = false;
  bool verbose = false;
  String? bundleRootArg;
  String? platformArg;
  int? portArg;
  int timeoutSeconds = 90;

  Future<int> run() async {
    _parseArgs();

    if (command == 'help' || command == '--help' || command == '-h') {
      _printHelp();
      return 0;
    }

    if (command == 'version' || command == '--version' || command == '-V') {
      stdout.writeln('global_dharma_sharing package CLI 1.0.0');
      return 0;
    }

    final context = await DesktopPackageContext.resolve(
      bundleRootOverride: bundleRootArg,
      platformOverride: platformArg,
    );

    await _runDoctor(context);

    if (command == 'gateway-smoke' || command == 'all') {
      await _runGatewaySmoke(context);
    } else if (command != 'doctor') {
      throw CliFailure('Unknown command: $command', 64);
    }

    final result = <String, dynamic>{
      'ok': checks.every((item) => item.ok),
      'command': command,
      'platform': context.platformKey,
      'bundleRoot': context.bundleRoot.path,
      'assetRoot': context.assetRoot.path,
      'platformAssetRoot': context.platformAssetRoot.path,
      'manifestPath': context.manifestFile.path,
      'nodePath': context.nodeFile.path,
      'openClawEntrypoint': context.openClawEntrypoint.path,
      'checks': checks.map((item) => item.toJson()).toList(),
    };

    if (jsonOutput) {
      writeJson(result);
    } else {
      stdout.writeln('global_dharma_sharing package CLI smoke passed');
      stdout.writeln('Platform: ${context.platformKey}');
      stdout.writeln('Bundle: ${context.bundleRoot.path}');
      stdout.writeln('Assets: ${context.assetRoot.path}');
      for (final check in checks) {
        stdout.writeln('  ok ${check.name}: ${check.message}');
      }
    }

    return 0;
  }

  void _parseArgs() {
    final remaining = <String>[];
    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      if (arg == '--json') {
        jsonOutput = true;
      } else if (arg == '--verbose') {
        verbose = true;
      } else if (arg == '--bundle-root') {
        index += 1;
        _requireValue(args, index, '--bundle-root');
        bundleRootArg = args[index];
      } else if (arg.startsWith('--bundle-root=')) {
        bundleRootArg = arg.substring('--bundle-root='.length);
      } else if (arg == '--platform') {
        index += 1;
        _requireValue(args, index, '--platform');
        platformArg = args[index];
      } else if (arg.startsWith('--platform=')) {
        platformArg = arg.substring('--platform='.length);
      } else if (arg == '--port') {
        index += 1;
        _requireValue(args, index, '--port');
        portArg = int.tryParse(args[index]);
        if (portArg == null) {
          throw CliFailure('Invalid --port: ${args[index]}', 64);
        }
      } else if (arg.startsWith('--port=')) {
        portArg = int.tryParse(arg.substring('--port='.length));
        if (portArg == null) throw CliFailure('Invalid --port: $arg', 64);
      } else if (arg == '--timeout-seconds') {
        index += 1;
        _requireValue(args, index, '--timeout-seconds');
        timeoutSeconds = int.tryParse(args[index]) ?? timeoutSeconds;
      } else if (arg.startsWith('--timeout-seconds=')) {
        timeoutSeconds =
            int.tryParse(arg.substring('--timeout-seconds='.length)) ??
            timeoutSeconds;
      } else if (arg.startsWith('-') &&
          arg != '--help' &&
          arg != '-h' &&
          arg != '--version' &&
          arg != '-V') {
        throw CliFailure('Unknown option: $arg', 64);
      } else {
        remaining.add(arg);
      }
    }

    if (remaining.isNotEmpty) {
      command = remaining.first;
      if (remaining.length > 1) {
        throw CliFailure(
          'Unexpected extra arguments: ${remaining.skip(1).join(' ')}',
          64,
        );
      }
    }

    if (timeoutSeconds < 5) timeoutSeconds = 5;
  }

  void _requireValue(List<String> values, int index, String option) {
    if (index >= values.length || values[index].startsWith('-')) {
      throw CliFailure('$option requires a value', 64);
    }
  }

  void _printHelp() {
    stdout.writeln(
      '''
Usage: $cliExecutableName <command> [options]

Commands:
  doctor          Validate the installed desktop package layout and embedded OpenClaw files.
  gateway-smoke   Start the bundled OpenClaw Gateway and verify health, models, and chat route wiring.
  all             Alias for gateway-smoke.
  version         Print this CLI version.

Options:
  --bundle-root <path>       Release bundle directory, .app path, or installed app directory.
  --platform <platform>      Override platform key, for example windows-x64, macos-arm64, linux-x64.
  --port <port>              Gateway port for gateway-smoke. Defaults to a deterministic free-ish port.
  --timeout-seconds <secs>   Gateway startup timeout. Default: 90.
  --json                    Print machine-readable JSON.
  --verbose                 Print extra gateway logs on failure.

Examples:
  $cliExecutableName doctor --json
  $cliExecutableName gateway-smoke --timeout-seconds 120
'''
          .trim(),
    );
  }

  Future<void> _runDoctor(DesktopPackageContext context) async {
    _check(
      'manifest',
      context.manifestFile.existsSync(),
      context.manifestFile.path,
    );
    _check(
      'platform manifest',
      context.platformManifest.isNotEmpty,
      context.platformKey,
    );
    _check(
      'node executable',
      context.nodeFile.existsSync(),
      context.nodeFile.path,
    );
    _check(
      'openclaw entrypoint',
      context.openClawEntrypoint.existsSync(),
      context.openClawEntrypoint.path,
    );
    _check(
      'openclaw package.json',
      context.openClawPackageJson.existsSync(),
      context.openClawPackageJson.path,
    );

    if (!Platform.isWindows) {
      final stat = context.nodeFile.statSync();
      final executable = (stat.mode & 0x49) != 0;
      _check(
        'node executable bit',
        executable,
        'mode=${stat.mode.toRadixString(8)}',
      );
    }

    final nodeVersion = await _runShortProcess(context.nodeFile.path, const [
      '--version',
    ], context.platformAssetRoot.path);
    _check('node runs', nodeVersion.exitCode == 0, nodeVersion.summary);

    final openClawVersion = await _runShortProcess(context.nodeFile.path, [
      context.openClawEntrypoint.path,
      '--version',
    ], context.platformAssetRoot.path);
    _check(
      'openclaw runs',
      openClawVersion.exitCode == 0,
      openClawVersion.summary,
    );
  }

  Future<void> _runGatewaySmoke(DesktopPackageContext context) async {
    final timeout = Duration(seconds: timeoutSeconds);
    final port = portArg ?? await _pickPort();
    final token = 'gds-${DateTime.now().microsecondsSinceEpoch}-$pid';
    final tempRoot = await Directory.systemTemp.createTemp(
      'gds-openclaw-smoke-',
    );
    final configDir = Directory(_join(tempRoot.path, 'config'))
      ..createSync(recursive: true);
    final stateDir = Directory(_join(tempRoot.path, 'state'))
      ..createSync(recursive: true);
    final agentDir = Directory(_join(tempRoot.path, 'agents'))
      ..createSync(recursive: true);
    final workspaceDir = Directory(_join(tempRoot.path, 'workspace'))
      ..createSync(recursive: true);
    final configFile = File(_join(configDir.path, 'openclaw.json'));
    configFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'gateway': <String, dynamic>{
          'mode': 'local',
          'port': port,
          'bind': 'loopback',
          'auth': <String, dynamic>{'mode': 'token', 'token': token},
          'http': <String, dynamic>{
            'endpoints': <String, dynamic>{
              'chatCompletions': <String, dynamic>{'enabled': true},
              'responses': <String, dynamic>{'enabled': true},
            },
          },
        },
        'agents': <String, dynamic>{
          'defaults': <String, dynamic>{'workspace': workspaceDir.path},
          'list': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'dacheng',
              'default': true,
              'workspace': workspaceDir.path,
            },
          ],
        },
      }),
    );

    Process? process;
    final logLines = <String>[];
    try {
      process = await Process.start(
        context.nodeFile.path,
        [
          context.openClawEntrypoint.path,
          'gateway',
          '--port',
          '$port',
          '--force',
          '--auth',
          'token',
          '--token',
          token,
        ],
        workingDirectory: context.platformAssetRoot.path,
        environment: <String, String>{
          ...Platform.environment,
          'OPENCLAW_CONFIG_PATH': configFile.path,
          'OPENCLAW_STATE_DIR': stateDir.path,
          'OPENCLAW_AGENT_DIR': agentDir.path,
          'OPENCLAW_WORKSPACE': workspaceDir.path,
          'OPENCLAW_GATEWAY_TOKEN': token,
          'OPENCLAW_SKIP_CHANNELS': '1',
          'OPENCLAW_SKIP_PROVIDERS': '1',
          'NO_COLOR': '1',
        },
        mode: ProcessStartMode.normal,
        runInShell: false,
      );
      _capture(process.stdout, logLines);
      _capture(process.stderr, logLines);

      final baseUri = Uri.parse('http://127.0.0.1:$port');
      final started = await _waitForGateway(
        baseUri,
        token,
        timeout,
        process,
        logLines,
      );
      _check('gateway starts', started, 'port=$port');

      final health = await _httpGet(
        baseUri.replace(path: '/health'),
        null,
        const Duration(seconds: 5),
      );
      _check(
        'gateway health route',
        health.statusCode >= 200 && health.statusCode < 500,
        'status=${health.statusCode}',
      );

      final models = await _httpGet(
        baseUri.replace(path: '/v1/models'),
        token,
        const Duration(seconds: 10),
      );
      _check(
        'openai models route',
        models.statusCode == 200,
        'status=${models.statusCode} body=${_compact(models.body)}',
      );

      final chat = await _httpPostJson(
        baseUri.replace(path: '/v1/chat/completions'),
        token,
        <String, dynamic>{},
        const Duration(seconds: 10),
      );
      final chatRouteOk =
          chat.statusCode != 404 &&
          chat.statusCode != 401 &&
          chat.statusCode != 403;
      _check(
        'openai chat route',
        chatRouteOk,
        'status=${chat.statusCode} body=${_compact(chat.body)}',
      );
    } finally {
      if (process != null) {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 5));
        } catch (_) {
          if (Platform.isWindows) {
            process.kill();
          } else {
            process.kill();
          }
        }
      }
      if (verbose || checks.any((item) => !item.ok)) {
        for (final line in logLines.take(80)) {
          stderr.writeln('[gateway] $line');
        }
      }
      try {
        tempRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<bool> _waitForGateway(
    Uri baseUri,
    String token,
    Duration timeout,
    Process process,
    List<String> logLines,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 1),
        onTimeout: () => -999999,
      );
      if (exitCode != -999999) {
        throw CliFailure(
          'Gateway exited before becoming ready: exitCode=$exitCode logs=${logLines.take(20).join(' | ')}',
        );
      }

      try {
        final models = await _httpGet(
          baseUri.replace(path: '/v1/models'),
          token,
          const Duration(seconds: 2),
        );
        if (models.statusCode == 200) return true;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw CliFailure(
      'Timed out waiting for gateway on $baseUri logs=${logLines.take(20).join(' | ')}',
    );
  }

  void _capture(Stream<List<int>> stream, List<String> lines) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final text = line.trim();
      if (text.isEmpty) return;
      lines.insert(0, text);
      if (lines.length > 200) lines.removeRange(200, lines.length);
    }, onError: (_) {});
  }

  Future<int> _pickPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<ProcessSummary> _runShortProcess(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    try {
      final result = await Process.run(
        executable,
        args,
        workingDirectory: workingDirectory,
        environment: <String, String>{...Platform.environment, 'NO_COLOR': '1'},
      ).timeout(const Duration(seconds: 20));
      final stdoutText = _compact(result.stdout.toString());
      final stderrText = _compact(result.stderr.toString());
      return ProcessSummary(
        result.exitCode,
        stderrText.isEmpty ? stdoutText : '$stdoutText $stderrText',
      );
    } catch (error) {
      return ProcessSummary(1, error.toString());
    }
  }

  Future<HttpResult> _httpGet(Uri uri, String? token, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(timeout);
      final body = await utf8.decodeStream(response).timeout(timeout);
      return HttpResult(response.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpResult> _httpPostJson(
    Uri uri,
    String token,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        ContentType.json.mimeType,
      );
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decodeStream(response).timeout(timeout);
      return HttpResult(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  void _check(String name, bool ok, String message) {
    final check = SmokeCheck(name, ok, message);
    checks.add(check);
    if (!ok) throw CliFailure('$name failed: $message');
  }

  void writeJson(Map<String, dynamic> value) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
  }
}

class DesktopPackageContext {
  DesktopPackageContext({
    required this.bundleRoot,
    required this.assetRoot,
    required this.platformKey,
    required this.manifestFile,
    required this.manifest,
    required this.platformManifest,
    required this.platformAssetRoot,
    required this.nodeFile,
    required this.openClawEntrypoint,
    required this.openClawPackageJson,
  });

  final Directory bundleRoot;
  final Directory assetRoot;
  final String platformKey;
  final File manifestFile;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> platformManifest;
  final Directory platformAssetRoot;
  final File nodeFile;
  final File openClawEntrypoint;
  final File openClawPackageJson;

  static Future<DesktopPackageContext> resolve({
    String? bundleRootOverride,
    String? platformOverride,
  }) async {
    final platformKey = platformOverride?.trim().isNotEmpty == true
        ? platformOverride!.trim()
        : _currentPlatformKey();
    final bundleRoot = _resolveBundleRoot(bundleRootOverride);
    final manifestFile = _findManifest(bundleRoot);
    if (!manifestFile.existsSync()) {
      throw CliFailure('OpenClaw manifest not found under ${bundleRoot.path}');
    }
    final assetRoot = manifestFile.parent;
    final manifest = _readJsonMap(manifestFile);
    final platforms = _asMap(manifest['platforms']);
    final platformManifest = _asMap(platforms[platformKey]);
    if (platformManifest.isEmpty) {
      throw CliFailure(
        'Manifest ${manifestFile.path} does not contain platform $platformKey',
      );
    }
    final nodeRel =
        (platformManifest['nodeExecutable'] ??
                (platformKey.startsWith('windows-')
                    ? 'node/node.exe'
                    : 'node/bin/node'))
            .toString();
    final cliRel =
        (platformManifest['cliEntrypoint'] ?? 'openclaw/openclaw.mjs')
            .toString();
    final platformAssetRoot = Directory(_join(assetRoot.path, platformKey));
    final nodeFile = File(_join(platformAssetRoot.path, _rel(nodeRel)));
    final openClawEntrypoint = File(
      _join(platformAssetRoot.path, _rel(cliRel)),
    );
    final openClawPackageJson = File(
      _join(platformAssetRoot.path, 'openclaw', 'package.json'),
    );

    return DesktopPackageContext(
      bundleRoot: bundleRoot,
      assetRoot: assetRoot,
      platformKey: platformKey,
      manifestFile: manifestFile,
      manifest: manifest,
      platformManifest: platformManifest,
      platformAssetRoot: platformAssetRoot,
      nodeFile: nodeFile,
      openClawEntrypoint: openClawEntrypoint,
      openClawPackageJson: openClawPackageJson,
    );
  }

  static Directory _resolveBundleRoot(String? override) {
    if (override != null && override.trim().isNotEmpty) {
      return Directory(File(override).absolute.path);
    }

    final executable = File(Platform.resolvedExecutable).absolute;
    final exeDir = executable.parent;
    if (_looksLikeMacContentsMacOS(exeDir)) {
      return exeDir.parent.parent;
    }
    return exeDir;
  }

  static bool _looksLikeMacContentsMacOS(Directory dir) {
    final normalized = dir.path.replaceAll('\\', '/');
    return normalized.endsWith('.app/Contents/MacOS') ||
        normalized.contains('.app/Contents/MacOS/');
  }

  static File _findManifest(Directory bundleRoot) {
    final candidates = <String>[
      _join(
        bundleRoot.path,
        'data',
        'flutter_assets',
        'assets',
        'openclaw',
        'bundle_manifest.json',
      ),
      _join(
        bundleRoot.path,
        'Contents',
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
        'assets',
        'openclaw',
        'bundle_manifest.json',
      ),
      _join(
        bundleRoot.path,
        'Contents',
        'Frameworks',
        'App.framework',
        'Versions',
        'A',
        'Resources',
        'flutter_assets',
        'assets',
        'openclaw',
        'bundle_manifest.json',
      ),
      _join(
        bundleRoot.path,
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
        'assets',
        'openclaw',
        'bundle_manifest.json',
      ),
      _join(
        bundleRoot.path,
        'Frameworks',
        'App.framework',
        'Versions',
        'A',
        'Resources',
        'flutter_assets',
        'assets',
        'openclaw',
        'bundle_manifest.json',
      ),
      _join(bundleRoot.path, 'assets', 'openclaw', 'bundle_manifest.json'),
    ];
    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) return file;
    }

    final found = _findFileBySuffix(
      bundleRoot,
      _rel('assets/openclaw/bundle_manifest.json'),
      maxDepth: 8,
    );
    if (found != null) return found;
    return File(candidates.first);
  }
}

class SmokeCheck {
  const SmokeCheck(this.name, this.ok, this.message);

  final String name;
  final bool ok;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'ok': ok,
    'message': message,
  };
}

class HttpResult {
  const HttpResult(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

class ProcessSummary {
  const ProcessSummary(this.exitCode, this.summary);
  final int exitCode;
  final String summary;
}

class CliFailure implements Exception {
  CliFailure(this.message, [this.exitCode = 1]);
  final String message;
  final int exitCode;
  @override
  String toString() => message;
}

String _currentPlatformKey() {
  final abi = Abi.current().toString().toLowerCase();
  if (Platform.isMacOS) {
    return abi.contains('arm64') ? 'macos-arm64' : 'macos-x64';
  }
  if (Platform.isWindows) {
    return abi.contains('arm64') ? 'windows-arm64' : 'windows-x64';
  }
  if (Platform.isLinux) {
    return abi.contains('arm64') ? 'linux-arm64' : 'linux-x64';
  }
  throw CliFailure('Unsupported desktop platform: ${Platform.operatingSystem}');
}

Map<String, dynamic> _readJsonMap(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw CliFailure('Expected JSON object in ${file.path}');
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _join(
  String a, [
  String? b,
  String? c,
  String? d,
  String? e,
  String? f,
  String? g,
  String? h,
  String? i,
  String? j,
  String? k,
  String? l,
  String? m,
  String? n,
]) {
  final parts = <String?>[
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (parts.isEmpty) return '';
  final separator = Platform.pathSeparator;
  var result = parts.first;
  for (final part in parts.skip(1)) {
    if (result.endsWith('/') || result.endsWith('\\')) {
      result = '$result${part.replaceAll(RegExp(r'^[\\/]+'), '')}';
    } else {
      result = '$result$separator${part.replaceAll(RegExp(r'^[\\/]+'), '')}';
    }
  }
  return result;
}

String _rel(String path) => path
    .replaceAll('/', Platform.pathSeparator)
    .replaceAll('\\', Platform.pathSeparator);

File? _findFileBySuffix(Directory root, String suffix, {int maxDepth = 6}) {
  if (!root.existsSync()) return null;
  final rootSegments = _splitPath(root.absolute.path).length;
  final queue = <Directory>[root];
  while (queue.isNotEmpty) {
    final dir = queue.removeAt(0);
    final depth = _splitPath(dir.absolute.path).length - rootSegments;
    if (depth > maxDepth) continue;
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final child in children) {
      if (child is File && child.path.endsWith(suffix)) return child;
      if (child is Directory && depth < maxDepth) queue.add(child);
    }
  }
  return null;
}

List<String> _splitPath(String path) =>
    path.split(RegExp(r'[\\/]+')).where((part) => part.isNotEmpty).toList();

String _compact(String value, [int maxLength = 240]) {
  final compacted = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compacted.length <= maxLength) return compacted;
  return '${compacted.substring(0, maxLength)}...';
}
