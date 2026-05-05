import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:quickjs/quickjs.dart';
import 'package:yaml/yaml.dart';

import 'runner_config.dart';

class PluginsCommand extends DewCommand {
  PluginsCommand({FileSystem fs = const LocalFileSystem()}) {
    addSubcommand(PluginsListCommand(fs: fs));
  }

  @override
  final String name = 'plugins';

  @override
  final String description =
      'List and manage playbook plugins configured for the current project.';

  @override
  Future<void> run() async => printUsage();
}

class PluginsListCommand extends DewCommand {
  final FileSystem _fs;
  final Future<ProjectContext> Function({FileSystem fs, Directory? from})
  _projectContextFinder;

  PluginsListCommand({
    FileSystem fs = const LocalFileSystem(),
    Future<ProjectContext> Function({FileSystem fs, Directory? from})?
    projectContextFinder,
  }) : _fs = fs,
       _projectContextFinder = projectContextFinder ?? ProjectContext.find;

  @override
  final String name = 'list';

  @override
  final String description = 'List available playbook plugins.';

  @override
  Future<void> run() async {
    final context = await _projectContextFinder(fs: _fs);
    final runnerConfig = context.config.runner;
    final pluginDirectory = context.resolveConfigPath(
      runnerConfig.pluginDirectory,
    );
    final pluginDir = _fs.directory(pluginDirectory);
    if (!await pluginDir.exists()) {
      print('No plugins found in $pluginDirectory.');
      return;
    }

    final entries = pluginDir.listSync().whereType<File>();
    final plugins = <String>[];
    for (final entry in entries) {
      if (p.extension(entry.path) != '.js') continue;
      final name = p.basename(entry.path);
      final base = p.basenameWithoutExtension(name);
      if (!plugins.contains(base)) plugins.add(base);
    }

    if (plugins.isEmpty) {
      print('No plugins found in $pluginDirectory.');
      return;
    }

    plugins.sort();
    for (final plugin in plugins) {
      print(plugin);
    }
  }
}

class RunCommand extends DewCommand {
  final FileSystem _fs;
  final PlaybookExecutor _executor;
  final Future<ProjectContext> Function({FileSystem fs, Directory? from})
  _projectContextFinder;

  RunCommand({
    FileSystem fs = const LocalFileSystem(),
    PlaybookExecutor? executor,
    Future<ProjectContext> Function({FileSystem fs, Directory? from})?
    projectContextFinder,
  }) : _fs = fs,
       _executor = executor ?? const _QuickJsPlaybookExecutor(),
       _projectContextFinder = projectContextFinder ?? ProjectContext.find;

  @override
  final String name = 'run';

  @override
  final String description =
      'Run a JavaScript playbook from the configured Dew plugins directory.';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      usageException('Missing playbook. Usage: dew run <playbook> [args].');
    }

    final requestedPlaybook = rest.first;
    final playbookArgs = rest.skip(1).toList();
    final context = await _projectContextFinder(fs: _fs);
    final runnerConfig = context.config.runner;
    final pluginDirectory = context.resolveConfigPath(
      runnerConfig.pluginDirectory,
    );
    final playbookPath = await _resolvePlaybookPath(
      context: context,
      pluginDirectory: pluginDirectory,
      requestedPlaybook: requestedPlaybook,
    );
    final playbookFile = _fs.file(playbookPath);
    if (!await playbookFile.exists()) {
      usageException('Playbook not found: $playbookPath');
    }

    final playbookCode = await playbookFile.readAsString();
    final output = await _executor.execute(
      code: playbookCode,
      playbookPath: playbookPath,
      playbook: requestedPlaybook,
      projectRoot: context.root,
      pluginDirectory: pluginDirectory,
      args: playbookArgs,
    );

    if (output.isNotEmpty) print(output);
  }

  Future<String> _findPlaybookPath(
    String pluginDirectory,
    String requestedPlaybook,
  ) async {
    final candidateWithExtension = p.join(
      pluginDirectory,
      p.extension(requestedPlaybook).isEmpty
          ? '$requestedPlaybook.js'
          : requestedPlaybook,
    );
    if (await _fs.file(candidateWithExtension).exists()) {
      return candidateWithExtension;
    }

    return p.join(pluginDirectory, requestedPlaybook);
  }

  Future<String> _resolvePlaybookPath({
    required ProjectContext context,
    required String pluginDirectory,
    required String requestedPlaybook,
  }) async {
    if (_isPathPlaybook(requestedPlaybook)) {
      return _resolveExplicitPlaybookPath(context, requestedPlaybook);
    }

    return _resolvePluginPlaybookPath(pluginDirectory, requestedPlaybook);
  }

  Future<String> _resolveExplicitPlaybookPath(
    ProjectContext context,
    String requestedPlaybook,
  ) async {
    final candidates = <String>[];
    if (p.isAbsolute(requestedPlaybook)) {
      candidates.add(p.normalize(requestedPlaybook));
    } else {
      candidates.add(p.normalize(p.join(context.root, requestedPlaybook)));
      candidates.add(requestedPlaybook);
      candidates.add(p.join(context.root, '.project', requestedPlaybook));
    }

    for (final candidate in candidates) {
      if (await _fs.file(candidate).exists()) {
        return p.normalize(candidate);
      }
      if (p.extension(candidate).isEmpty) {
        final withJs = '$candidate.js';
        if (await _fs.file(withJs).exists()) {
          return p.normalize(withJs);
        }
      }
    }

    usageException('Playbook not found: $requestedPlaybook');
  }

  Future<String> _resolvePluginPlaybookPath(
    String pluginDirectory,
    String requestedPlaybook,
  ) async {
    final pluginName = p.basenameWithoutExtension(requestedPlaybook);
    final pluginDir = _fs.directory(p.join(pluginDirectory, pluginName));
    if (await pluginDir.exists()) {
      final manifestPath = p.join(pluginDir.path, 'dew.yaml');
      final manifest = _fs.file(manifestPath);
      if (await manifest.exists()) {
        final raw = loadYaml(await manifest.readAsString());
        final manifestMap = raw is YamlMap ? raw : null;
        final entrypoint = manifestMap == null
            ? null
            : manifestMap['entrypoint']?.toString();

        if (entrypoint == null || entrypoint.trim().isEmpty) {
          usageException('Plugin "$pluginName" is missing an entrypoint.');
        }

        final entrypointPath = p.join(pluginDir.path, entrypoint);
        if (await _fs.file(entrypointPath).exists()) {
          return p.normalize(entrypointPath);
        }
        usageException(
          'Plugin "$pluginName" entrypoint not found: $entrypoint',
        );
      }

      final fallbackPluginPath = p.join(pluginDir.path, '$pluginName.js');
      if (await _fs.file(fallbackPluginPath).exists()) {
        return fallbackPluginPath;
      }
    }

    return _findPlaybookPath(pluginDirectory, requestedPlaybook);
  }

  bool _isPathPlaybook(String requestedPlaybook) {
    return p.isAbsolute(requestedPlaybook) ||
        requestedPlaybook.startsWith('.') ||
        requestedPlaybook.contains('/') ||
        requestedPlaybook.contains('\\');
  }
}

abstract interface class PlaybookExecutor {
  Future<String> execute({
    required String code,
    required String playbookPath,
    required String playbook,
    required String projectRoot,
    required String pluginDirectory,
    required List<String> args,
  });
}

class _QuickJsPlaybookExecutor implements PlaybookExecutor {
  const _QuickJsPlaybookExecutor();
  static final Future<String> _preambleSource = _loadPreamble();

  @override
  Future<String> execute({
    required String code,
    required String playbookPath,
    required String playbook,
    required String projectRoot,
    required String pluginDirectory,
    required List<String> args,
  }) async {
    return _executeWithQuickJsPackage(
      code: code,
      playbookPath: playbookPath,
      playbook: playbook,
      projectRoot: projectRoot,
      pluginDirectory: pluginDirectory,
      args: args,
    );
  }

  Future<String> _executeWithQuickJsPackage({
    required String code,
    required String playbookPath,
    required String playbook,
    required String projectRoot,
    required String pluginDirectory,
    required List<String> args,
  }) async {
    final preamble = await _preambleSource;
    final context = jsonEncode(<String, dynamic>{
      'playbook': playbook,
      'project_root': projectRoot,
      'plugin_directory': pluginDirectory,
    });
    final encodedArgs = jsonEncode(args);
    final wrapped =
        '''
(() => {
  const __dewContext = $context;
  const __dewArgs = $encodedArgs;

  $preamble

  $code

  let result;
  if (typeof run === 'function') {
    result = run(__dewContext, __dewArgs);
  } else if (typeof execute === 'function') {
    result = execute(__dewContext, __dewArgs);
  } else if (typeof main === 'function') {
    result = main(__dewContext, __dewArgs);
  } else {
    throw new Error(
      'Playbook must define run(context, args), execute(context, args), or main(context, args).'
    );
  }

  return JSON.stringify(result);
})();''';

    final manager = await JsEngineManager.create();
    final engine = await manager.createEngine(playbookPath);

    try {
      final result = await engine.eval(wrapped);
      if (result.isError) {
        throw ArgumentError(result.stderr ?? result.value);
      }

      final parts = <String>[];
      if (result.stdout != null) {
        final trimmed = result.stdout!.trim();
        if (trimmed.isNotEmpty) parts.add(trimmed);
      }

      final decoded = _decodeJsResultValue(result.value);
      if (decoded.isNotEmpty) parts.add(decoded);

      return parts.join('\n');
    } finally {
      await engine.dispose();
      await manager.dispose();
    }
  }

  String _decodeJsResultValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'undefined' || trimmed == 'null') {
      return '';
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String || decoded is num || decoded is bool) {
        return '$decoded';
      }
      final encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return trimmed;
    }
  }

  static Future<String> _loadPreamble() async {
    try {
      final uri = await Isolate.resolvePackageUri(_preambleAssetUri);
      if (uri != null) {
        final file = io.File.fromUri(uri);
        if (await file.exists()) {
          return file.readAsString();
        }
      }
    } catch (_) {
      // Intentionally ignore and fall back to embedded preamble.
    }
    return _defaultPreamble;
  }
}

final Uri _preambleAssetUri = Uri.parse(
  'package:dew_runner/assets/preamble.js',
);

const String _defaultPreamble = '''
(() => {
  const context = globalThis.__dewContext || {};
  const args = globalThis.__dewArgs || [];

  const pretty = (value) => {
    if (value === undefined) {
      return 'undefined';
    }
    if (value === null) {
      return 'null';
    }
    if (typeof value === 'string') {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (_) {
      return String(value);
    }
  };

  if (globalThis.dew === undefined) {
    globalThis.dew = {};
  }

  globalThis.dew.context = context;
  globalThis.dew.args = args;

  const write = (prefix, values) => {
    if (typeof print === 'function') {
      print(
        prefix
          ? [prefix, ...values]
            .map(pretty)
            .join(' ')
          : values.map(pretty).join(' '),
      );
      return;
    }
    if (typeof console !== 'undefined' && typeof console.log === 'function') {
      console.log(prefix ? [prefix, ...values] : values);
    }
  };

  globalThis.dew.log = (...values) => write('', values);
  globalThis.dew.info = (...values) => write('[info]', values);
  globalThis.dew.warn = (...values) => write('[warn]', values);
  globalThis.dew.error = (...values) => write('[error]', values);
})();
''';
