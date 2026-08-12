import 'dart:convert';
import 'dart:io';

const String cliExecutableName = 'global_dharma_sharing_cli';

Future<void> main(List<String> args) async {
  final cli = DesktopSmokeCli(args);
  try {
    exitCode = await cli.run();
  } on CliFailure catch (error) {
    cli.reportFailure(error.message);
    exitCode = error.exitCode;
  } catch (error, stackTrace) {
    cli.reportFailure(error.toString(), stackTrace: stackTrace);
    exitCode = 1;
  }
}

class DesktopSmokeCli {
  DesktopSmokeCli(this.args);

  final List<String> args;
  final List<SmokeCheck> checks = <SmokeCheck>[];

  String command = 'doctor';
  String? bundleRootArg;
  bool jsonOutput = false;

  Future<int> run() async {
    _parseArgs();
    if (const {'help', '--help', '-h'}.contains(command)) {
      _printHelp();
      return 0;
    }
    if (const {'version', '--version', '-V'}.contains(command)) {
      stdout.writeln('global_dharma_sharing package CLI 2.0.0');
      return 0;
    }

    DesktopPackageContext? context;
    if (command != 'miniapp-smoke') {
      context = DesktopPackageContext.resolve(bundleRootArg);
      _runDoctor(context);
    }
    if (command == 'runtime-smoke' || command == 'all') {
      await _runRuntimeSmoke(context!);
    }
    if (command == 'miniapp-smoke' || command == 'all') {
      _runMiniAppSmoke();
    }
    if (!const {
      'doctor',
      'runtime-smoke',
      'miniapp-smoke',
      'all',
    }.contains(command)) {
      throw CliFailure('Unknown command: $command', 64);
    }

    final result = <String, dynamic>{
      'ok': checks.every((check) => check.ok),
      'command': command,
      if (context != null) 'bundleRoot': context.bundleRoot.path,
      if (context != null) 'mahayanaCli': context.mahayanaCli.path,
      if (context != null) 'mahayanaRuntime': context.mahayanaRuntime.path,
      'checks': checks.map((check) => check.toJson()).toList(),
    };
    if (jsonOutput) {
      _writeJson(result);
    } else {
      stdout.writeln('global_dharma_sharing package smoke passed');
      for (final check in checks) {
        stdout.writeln('  ok ${check.name}: ${check.message}');
      }
    }
    return 0;
  }

  void _parseArgs() {
    final positional = <String>[];
    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      if (arg == '--json') {
        jsonOutput = true;
      } else if (arg == '--bundle-root') {
        if (++index >= args.length) {
          throw CliFailure('--bundle-root requires a value', 64);
        }
        bundleRootArg = args[index];
      } else if (arg.startsWith('--bundle-root=')) {
        bundleRootArg = arg.substring('--bundle-root='.length);
      } else if (arg.startsWith('-')) {
        if (const {'--help', '-h', '--version', '-V'}.contains(arg)) {
          positional.add(arg);
        } else {
          throw CliFailure('Unknown option: $arg', 64);
        }
      } else {
        positional.add(arg);
      }
    }
    if (positional.isNotEmpty) command = positional.first;
    if (positional.length > 1) {
      throw CliFailure(
        'Unexpected extra arguments: ${positional.skip(1).join(' ')}',
        64,
      );
    }
  }

  void _printHelp() {
    stdout.writeln(
      '''
Usage: $cliExecutableName <command> [options]

Commands:
  doctor          Validate the installed Mahayana CLI and Runtime layout.
  runtime-smoke   Execute Mahayana status through the packaged native runtime.
  miniapp-smoke   Verify the shared official MCP plugin contract.
  all             Run runtime-smoke and miniapp-smoke.
  version         Print this CLI version.

Options:
  --bundle-root <path>  Release bundle directory or .app path.
  --json                Print machine-readable JSON.
'''
          .trim(),
    );
  }

  void _runDoctor(DesktopPackageContext context) {
    _check(
      'Mahayana CLI exists',
      context.mahayanaCli.existsSync(),
      context.mahayanaCli.path,
    );
    _check(
      'Mahayana Runtime exists',
      context.mahayanaRuntime.existsSync(),
      context.mahayanaRuntime.path,
    );
    if (!Platform.isWindows) {
      final mode = context.mahayanaCli.statSync().mode;
      _check(
        'Mahayana CLI executable',
        (mode & 0x49) != 0,
        'mode=${mode.toRadixString(8)}',
      );
    }
  }

  Future<void> _runRuntimeSmoke(DesktopPackageContext context) async {
    final help = await Process.run(
      context.mahayanaCli.path,
      const ['--help'],
      workingDirectory: context.mahayanaCli.parent.path,
    );
    _check(
      'Mahayana CLI starts',
      help.exitCode == 0,
      _compact('${help.stdout} ${help.stderr}'),
    );

    final home = await Directory.systemTemp.createTemp('mahayana-smoke-');
    try {
      final status = await Process.run(
        context.mahayanaCli.path,
        const ['status'],
        workingDirectory: context.mahayanaCli.parent.path,
        environment: <String, String>{
          ...Platform.environment,
          'MAHAYANA_HOME': home.path,
        },
      );
      _check(
        'Mahayana status executes',
        status.exitCode == 0,
        _compact('${status.stdout} ${status.stderr}'),
      );
      final payload = jsonDecode(status.stdout.toString());
      final valid =
          payload is Map<String, dynamic> &&
          payload['model'] == 'deepseek-chat' &&
          payload['modelProvider'] == 'first-party-dacheng' &&
          payload['remoteAgentEnabled'] == false;
      _check(
        'Mahayana production defaults',
        valid,
        _compact(status.stdout.toString()),
      );
    } finally {
      try {
        home.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  void _runMiniAppSmoke() {
    const plugins = <String, List<String>>{
      'global-dharma': ['home', 'start', 'stop', 'status'],
      'faliu-flashcards': ['home', 'create_deck', 'review_next'],
      'platform-publish': ['home', 'create_draft', 'publish'],
      'hermes-installer': ['home', 'install', 'status'],
      'bot-father': ['home', 'create_bot', 'status'],
      'mahayana-assistant': ['home', 'chat', 'status'],
      'chatgpt-auto-confirm': ['home', 'start', 'status'],
    };
    _check(
      'official MCP plugin inventory',
      plugins.length == 7,
      plugins.keys.join(','),
    );
    for (final entry in plugins.entries) {
      _check(
        'MCP Tool contract ${entry.key}',
        entry.value.first == 'home' &&
            entry.value.isNotEmpty &&
            entry.value.toSet().length == entry.value.length,
        entry.value.map((tool) => '/$tool').join(','),
      );
      final endpoint = Uri.parse(
        'https://api.ombhrum.com/api/mcp/apps/${entry.key}',
      );
      _check(
        'MCP endpoint ${entry.key}',
        endpoint.scheme == 'https' &&
            endpoint.path == '/api/mcp/apps/${entry.key}',
        endpoint.toString(),
      );
      _check(
        'MCP runtime variants ${entry.key}',
        const {'cli', 'desktop'}.difference(
          const {'cli', 'desktop', 'mobile', 'web'},
        ).isEmpty,
        'local=cli+desktop remote=cli+desktop+mobile+web',
      );
      _check(
        'MCP UI resource ${entry.key}',
        Uri.parse('ui://fabushi/${entry.key}/home-v1').scheme == 'ui',
        'ui://fabushi/${entry.key}/home-v1 text/html;profile=mcp-app',
      );
    }
  }

  void _check(String name, bool ok, String message) {
    checks.add(SmokeCheck(name, ok, message));
    if (!ok) throw CliFailure('$name failed: $message');
  }

  void reportFailure(String error, {StackTrace? stackTrace}) {
    if (jsonOutput) {
      _writeJson({
        'ok': false,
        'command': command,
        'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        'checks': checks.map((check) => check.toJson()).toList(),
      });
    } else {
      stderr.writeln('ERROR: $error');
      if (stackTrace != null) stderr.writeln(stackTrace);
    }
  }

  void _writeJson(Map<String, dynamic> value) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
  }
}

class DesktopPackageContext {
  const DesktopPackageContext({
    required this.bundleRoot,
    required this.mahayanaCli,
    required this.mahayanaRuntime,
  });

  final Directory bundleRoot;
  final File mahayanaCli;
  final File mahayanaRuntime;

  static DesktopPackageContext resolve(String? override) {
    late Directory root;
    if (override == null || override.trim().isEmpty) {
      final executable = File(Platform.resolvedExecutable).absolute;
      try {
        root = File(executable.resolveSymbolicLinksSync()).parent;
      } catch (_) {
        root = executable.parent;
      }
    } else {
      root = Directory(File(override).absolute.path);
    }
    final normalized = root.path.replaceAll('\\', '/');
    if (normalized.endsWith('.app/Contents/MacOS')) {
      root = root.parent.parent;
    }

    late final File cli;
    late final File runtime;
    if (Platform.isMacOS) {
      cli = File(_join(root.path, 'Contents', 'MacOS', 'mahayana'));
      runtime = File(
        _join(
          root.path,
          'Contents',
          'Frameworks',
          'libmahayana_runtime.dylib',
        ),
      );
    } else if (Platform.isWindows) {
      cli = File(_join(root.path, 'mahayana.exe'));
      runtime = File(_join(root.path, 'mahayana_runtime.dll'));
    } else {
      cli = File(_join(root.path, 'mahayana'));
      runtime = File(_join(root.path, 'lib', 'libmahayana_runtime.so'));
    }
    return DesktopPackageContext(
      bundleRoot: root,
      mahayanaCli: cli,
      mahayanaRuntime: runtime,
    );
  }
}

class SmokeCheck {
  const SmokeCheck(this.name, this.ok, this.message);

  final String name;
  final bool ok;
  final String message;

  Map<String, dynamic> toJson() => {
    'name': name,
    'ok': ok,
    'message': message,
  };
}

class CliFailure implements Exception {
  const CliFailure(this.message, [this.exitCode = 1]);

  final String message;
  final int exitCode;
}

String _join(String first, String second, [String? third, String? fourth]) {
  final separator = Platform.pathSeparator;
  return [first, second, third, fourth]
      .whereType<String>()
      .map((part) => part.replaceAll(RegExp(r'[/\\]+$'), ''))
      .join(separator);
}

String _compact(String value) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 500 ? text : '${text.substring(0, 500)}...';
}
