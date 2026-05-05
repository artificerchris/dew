import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

import 'infra_repository.dart';
import 'infra_runtime.dart';
import 'service_manifest.dart';

/// Root `dew infra` command.
class InfraCommand extends DewCommand {
  InfraCommand({
    FileSystem fs = const LocalFileSystem(),
    ContainerRuntimeRegistry? runtimeRegistry,
  }) : runtimeRegistry =
           runtimeRegistry ??
           ContainerRuntimeRegistry([PodmanQuadletRuntime(fs: fs)]) {
    argParser
      ..addOption(
        'project',
        help:
            'Project root. Defaults to walking upward until .project/dew.yaml is found.',
      )
      ..addOption(
        'infra-dir',
        help: 'Infrastructure root. Defaults to .project/infrastructure.',
      )
      ..addFlag('json', negatable: false, help: 'Machine-readable output.')
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print intended actions without applying them.',
      )
      ..addFlag(
        'yes',
        negatable: false,
        help: 'Skip confirmation for operations that change state.',
      )
      ..addOption(
        'scope',
        allowed: ['user', 'system'],
        defaultsTo: 'user',
        help: 'Quadlet/systemd scope.',
      );

    addSubcommand(
      InfraListCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    addSubcommand(
      InfraShowCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    addSubcommand(
      InfraValidateCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    addSubcommand(
      InfraConfigureCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    addSubcommand(
      InfraInitCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    for (final commandName in [
      'install',
      'uninstall',
      'up',
      'down',
      'restart',
      'status',
    ]) {
      addSubcommand(
        InfraRuntimeCommand(
          commandName,
          fs: fs,
          runtimeRegistry: this.runtimeRegistry,
        ),
      );
    }
    addSubcommand(
      InfraLogsCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
    addSubcommand(
      InfraDeleteCommand(fs: fs, runtimeRegistry: this.runtimeRegistry),
    );
  }

  final ContainerRuntimeRegistry runtimeRegistry;

  @override
  final String name = 'infra';

  @override
  final String description = 'Manage project infrastructure services.';

  @override
  Future<void> run() async => printUsage();
}

abstract class _InfraSubcommand extends DewCommand {
  _InfraSubcommand({required this.fs, required this.runtimeRegistry});

  final FileSystem fs;
  final ContainerRuntimeRegistry runtimeRegistry;

  Future<_InfraEnvironment> _environment() async {
    final options = _infraOptions();
    final projectArg = options['project'] as String?;
    final projectDirectory = projectArg == null
        ? null
        : fs.directory(_resolveFromCwd(projectArg));
    final projectContext = await ProjectContext.find(
      fs: fs,
      from: projectDirectory,
    );
    final infraArg = options['infra-dir'] as String?;
    final infraDir = infraArg == null
        ? p.join(projectContext.root, '.project', 'infrastructure')
        : _resolveProjectPath(projectContext.root, infraArg);
    return _InfraEnvironment(
      projectContext: projectContext,
      options: options,
      repository: InfraRepository(infraDir: infraDir, fs: fs),
      validator: InfraValidator(fs: fs),
      runtimeRegistry: runtimeRegistry,
      scope: InfraScope.parse(options['scope'] as String),
      json: options['json'] as bool,
      dryRun: options['dry-run'] as bool,
      yes: options['yes'] as bool,
    );
  }

  ArgResults _infraOptions() => (parent as InfraCommand).argResults!;

  String _requiredServiceArg([String? usage]) {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      usageException(usage ?? 'Missing service.');
    }
    return rest.first;
  }

  String _resolveFromCwd(String value) {
    if (p.isAbsolute(value)) return p.normalize(value);
    return p.normalize(p.join(fs.currentDirectory.path, value));
  }

  String _resolveProjectPath(String root, String value) {
    if (p.isAbsolute(value)) return p.normalize(value);
    return p.normalize(p.join(root, value));
  }
}

class _InfraEnvironment {
  const _InfraEnvironment({
    required this.projectContext,
    required this.options,
    required this.repository,
    required this.validator,
    required this.runtimeRegistry,
    required this.scope,
    required this.json,
    required this.dryRun,
    required this.yes,
  });

  final ProjectContext projectContext;
  final ArgResults options;
  final InfraRepository repository;
  final InfraValidator validator;
  final ContainerRuntimeRegistry runtimeRegistry;
  final InfraScope scope;
  final bool json;
  final bool dryRun;
  final bool yes;

  ContainerRuntime runtimeFor(InfraServiceManifest manifest) =>
      runtimeRegistry.forKind(manifest.runtime);
}

class InfraListCommand extends _InfraSubcommand {
  InfraListCommand({required super.fs, required super.runtimeRegistry});

  @override
  final String name = 'list';

  @override
  final String description = 'List infrastructure services.';

  @override
  Future<void> run() async {
    final env = await _environment();
    final manifests = await env.repository.list();
    if (env.json) {
      print(
        jsonEncode(manifests.map((manifest) => manifest.toJson()).toList()),
      );
      return;
    }
    if (manifests.isEmpty) {
      print('No infrastructure services found.');
      return;
    }
    for (final manifest in manifests) {
      print('${manifest.id}\t${manifest.name}\t${manifest.unit}');
    }
  }
}

class InfraShowCommand extends _InfraSubcommand {
  InfraShowCommand({required super.fs, required super.runtimeRegistry});

  @override
  final String name = 'show';

  @override
  final String description = 'Show service manifest and runtime details.';

  @override
  Future<void> run() async {
    final service = _requiredServiceArg('Usage: dew infra show <service>.');
    final env = await _environment();
    final manifest = await env.repository.get(service);
    final runtime = env.runtimeFor(manifest);
    final installed = await runtime.isInstalled(manifest, env.scope);
    final details = {
      ...manifest.toJson(),
      'installed': installed,
      'install_target': quadletSearchPath(
        env.scope,
        environment: io.Platform.environment,
      ),
      'scope': env.scope.name,
    };
    if (env.json) {
      print(jsonEncode(details));
      return;
    }
    for (final entry in details.entries) {
      if (entry.value == null) continue;
      print('${entry.key}: ${entry.value}');
    }
  }
}

class InfraValidateCommand extends _InfraSubcommand {
  InfraValidateCommand({required super.fs, required super.runtimeRegistry}) {
    argParser.addFlag('all', negatable: false, help: 'Validate all services.');
  }

  @override
  final String name = 'validate';

  @override
  final String description = 'Validate service manifests and referenced files.';

  @override
  Future<void> run() async {
    final env = await _environment();
    final rest = argResults?.rest ?? const [];
    final target = rest.isEmpty ? null : rest.first;
    final validateAll =
        (argResults?['all'] as bool? ?? false) || target == null;
    final manifests = validateAll
        ? await env.repository.list()
        : [await env.repository.get(target)];
    final issues = <InfraValidationIssue>[];
    for (final manifest in manifests) {
      issues.addAll(await env.validator.validate(manifest));
    }

    if (env.json) {
      print(
        jsonEncode({
          'valid': issues.isEmpty,
          'issues': issues.map((issue) => issue.toJson()).toList(),
        }),
      );
    } else if (issues.isEmpty) {
      print('Infrastructure manifests are valid.');
    } else {
      for (final issue in issues) {
        print(issue);
      }
    }
    if (issues.isNotEmpty) io.exitCode = 1;
  }
}

class InfraConfigureCommand extends _InfraSubcommand {
  InfraConfigureCommand({required super.fs, required super.runtimeRegistry}) {
    argParser
      ..addOption('file', help: 'JSON configuration file for apply.')
      ..addMultiOption('set', help: 'Set a dotted configuration key.');
  }

  @override
  final String name = 'configure';

  @override
  final String description =
      'Inspect or apply service configuration schema values.';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      usageException(
        'Usage: dew infra configure <service> [schema|show|apply].',
      );
    }
    final env = await _environment();
    final manifest = await env.repository.get(rest.first);
    final action = rest.length > 1 ? rest[1] : 'tui';
    switch (action) {
      case 'schema':
        await _printSchema(env, manifest.configureSchemaPath);
      case 'show':
        await _printPayload(env, manifest.activeConfigurePath);
      case 'apply':
        await _applyPayload(
          env,
          schemaPath: manifest.configureSchemaPath,
          outputPath: manifest.activeConfigurePath,
        );
      case 'tui':
        usageException(
          'Interactive schema editor is not implemented yet. '
          'Use "dew infra configure ${manifest.id} schema|show|apply".',
        );
      default:
        usageException('Unknown configure action "$action".');
    }
  }
}

class InfraInitCommand extends _InfraSubcommand {
  InfraInitCommand({required super.fs, required super.runtimeRegistry}) {
    argParser
      ..addOption('file', help: 'JSON initialization file for run.')
      ..addMultiOption('set', help: 'Set a dotted initialization key.');
  }

  @override
  final String name = 'init';

  @override
  final String description = 'Inspect or run service initialization options.';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      usageException('Usage: dew infra init <service> [schema|run].');
    }
    final env = await _environment();
    final manifest = await env.repository.get(rest.first);
    final action = rest.length > 1 ? rest[1] : 'tui';
    switch (action) {
      case 'schema':
        await _printSchema(env, manifest.initSchemaPath);
      case 'run':
        await _applyPayload(
          env,
          schemaPath: manifest.initSchemaPath,
          outputPath: manifest.activeInitPath,
        );
      case 'tui':
        usageException(
          'Interactive schema editor is not implemented yet. '
          'Use "dew infra init ${manifest.id} schema|run".',
        );
      default:
        usageException('Unknown init action "$action".');
    }
  }
}

class InfraRuntimeCommand extends _InfraSubcommand {
  InfraRuntimeCommand(
    this.name, {
    required super.fs,
    required super.runtimeRegistry,
  }) {
    argParser.addFlag('all', negatable: false, help: 'Apply to all services.');
  }

  @override
  final String name;

  @override
  String get description => switch (name) {
    'install' => 'Install service runtime files.',
    'uninstall' => 'Uninstall service runtime files.',
    'up' => 'Install, reload, and start services.',
    'down' => 'Stop services.',
    'restart' => 'Restart services.',
    'status' => 'Show service status.',
    _ => 'Manage infrastructure services.',
  };

  @override
  Future<void> run() async {
    final env = await _environment();
    final manifests = await _targetServices(env, allowAll: true);
    final results = <Map<String, Object?>>[];
    for (final manifest in manifests) {
      final runtime = env.runtimeFor(manifest);
      final result = await _runRuntimeCommand(env, manifest, runtime);
      _printRuntimeResult(env, manifest, result);
      results.add({'service': manifest.id, ...result.toJson()});
    }
    if (env.json) print(jsonEncode(results));
  }

  Future<InfraRuntimeResult> _runRuntimeCommand(
    _InfraEnvironment env,
    InfraServiceManifest manifest,
    ContainerRuntime runtime,
  ) async {
    switch (name) {
      case 'install':
        return runtime.install(manifest, scope: env.scope, dryRun: env.dryRun);
      case 'uninstall':
        return runtime.uninstall(
          manifest,
          scope: env.scope,
          dryRun: env.dryRun,
        );
      case 'up':
        final results = <InfraRuntimeResult>[];
        if (!await runtime.isInstalled(manifest, env.scope)) {
          results.add(
            await runtime.install(
              manifest,
              scope: env.scope,
              dryRun: env.dryRun,
            ),
          );
        }
        results.add(await runtime.reload(scope: env.scope, dryRun: env.dryRun));
        results.add(
          await runtime.start(manifest, scope: env.scope, dryRun: env.dryRun),
        );
        return _combineRuntimeResults(results);
      case 'down':
        return runtime.stop(manifest, scope: env.scope, dryRun: env.dryRun);
      case 'restart':
        return runtime.restart(manifest, scope: env.scope, dryRun: env.dryRun);
      case 'status':
        return runtime.status(manifest, scope: env.scope);
      default:
        throw StateError('Unknown runtime command $name.');
    }
  }
}

class InfraLogsCommand extends _InfraSubcommand {
  InfraLogsCommand({required super.fs, required super.runtimeRegistry}) {
    argParser
      ..addFlag('follow', abbr: 'f', negatable: false, help: 'Follow logs.')
      ..addOption('lines', defaultsTo: '200', help: 'Number of log lines.');
  }

  @override
  final String name = 'logs';

  @override
  final String description = 'Show service logs.';

  @override
  Future<void> run() async {
    final env = await _environment();
    final manifest = await env.repository.get(
      _requiredServiceArg('Usage: dew infra logs <service>.'),
    );
    final lines = int.tryParse(argResults?['lines'] as String? ?? '') ?? 200;
    final result = await env
        .runtimeFor(manifest)
        .logs(
          manifest,
          scope: env.scope,
          follow: argResults?['follow'] as bool? ?? false,
          lines: lines,
        );
    _printRuntimeResult(env, manifest, result);
    if (env.json) {
      print(jsonEncode({'service': manifest.id, ...result.toJson()}));
    }
  }
}

class InfraDeleteCommand extends _InfraSubcommand {
  InfraDeleteCommand({required super.fs, required super.runtimeRegistry}) {
    argParser
      ..addFlag(
        'container',
        negatable: false,
        help: 'Delete the named container runtime artifact.',
      )
      ..addFlag(
        'data',
        negatable: false,
        help: 'Delete service data artifacts. Requires --yes.',
      )
      ..addFlag('all', negatable: false, help: 'Apply to all services.');
  }

  @override
  final String name = 'delete';

  @override
  final String description = 'Delete service runtime artifacts.';

  @override
  Future<void> run() async {
    final env = await _environment();
    final deleteData = argResults?['data'] as bool? ?? false;
    if (deleteData && !env.yes) {
      usageException('--data requires --yes.');
    }
    final manifests = await _targetServices(env, allowAll: true);
    final results = <Map<String, Object?>>[];
    for (final manifest in manifests) {
      final result = await env
          .runtimeFor(manifest)
          .delete(
            manifest,
            scope: env.scope,
            deleteContainer: argResults?['container'] as bool? ?? false,
            deleteData: deleteData,
            dryRun: env.dryRun,
          );
      _printRuntimeResult(env, manifest, result);
      results.add({'service': manifest.id, ...result.toJson()});
    }
    if (env.json) print(jsonEncode(results));
  }
}

Future<List<InfraServiceManifest>> _targetServices(
  _InfraEnvironment env, {
  required bool allowAll,
}) async {
  final all = (env.options.command?['all'] as bool?) ?? false;
  final rest = env.options.command?.rest ?? const <String>[];
  if (all) return env.repository.list();
  if (rest.isEmpty) {
    throw UsageException('Missing service. Use a service id or --all.', '');
  }
  return [await env.repository.get(rest.first)];
}

Future<void> _printSchema(_InfraEnvironment env, String? schemaPath) async {
  if (schemaPath == null) throw ArgumentError('No schema path is declared.');
  final file = env.repository.fs.file(schemaPath);
  if (!await file.exists()) {
    throw ArgumentError('Schema not found: $schemaPath');
  }
  print(await file.readAsString());
}

Future<void> _printPayload(_InfraEnvironment env, String path) async {
  final file = env.repository.fs.file(path);
  if (!await file.exists()) {
    if (env.json) {
      print(jsonEncode(<String, Object?>{}));
    } else {
      print('No active configuration found at $path.');
    }
    return;
  }
  print(await file.readAsString());
}

Future<void> _applyPayload(
  _InfraEnvironment env, {
  required String? schemaPath,
  required String outputPath,
}) async {
  final payload = <String, dynamic>{};
  final command = env.options.command!;
  final filePath = command['file'] as String?;
  if (filePath != null) {
    payload.addAll(_readJsonObject(env, _resolveAgainstProject(env, filePath)));
  }
  for (final assignment in command['set'] as List<String>? ?? const []) {
    _applyAssignment(payload, assignment);
  }
  await _validatePayload(env, schemaPath, payload);
  if (env.dryRun) {
    print('Would write $outputPath');
    return;
  }
  final file = env.repository.fs.file(outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  if (env.json) {
    print(jsonEncode({'path': outputPath, 'config': payload}));
  } else {
    print('Wrote $outputPath');
  }
}

Map<String, dynamic> _readJsonObject(_InfraEnvironment env, String path) {
  final file = env.repository.fs.file(path);
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry('$key', value));
  }
  throw FormatException('Expected JSON object in $path.');
}

Future<void> _validatePayload(
  _InfraEnvironment env,
  String? schemaPath,
  Map<String, dynamic> payload,
) async {
  if (schemaPath == null) return;
  final schemaFile = env.repository.fs.file(schemaPath);
  if (!await schemaFile.exists()) return;
  final decoded = jsonDecode(await schemaFile.readAsString());
  final result = JsonSchema.create(decoded).validate(payload);
  if (!result.isValid) {
    throw FormatException(result.errors.map((error) => '$error').join('\n'));
  }
}

void _applyAssignment(Map<String, dynamic> payload, String assignment) {
  final index = assignment.indexOf('=');
  if (index <= 0) {
    throw FormatException('Expected key=value assignment, got "$assignment".');
  }
  final key = assignment.substring(0, index);
  final value = _parseValue(assignment.substring(index + 1));
  var current = payload;
  final parts = key.split('.');
  for (final part in parts.take(parts.length - 1)) {
    current =
        current.putIfAbsent(part, () => <String, dynamic>{})
            as Map<String, dynamic>;
  }
  current[parts.last] = value;
}

Object? _parseValue(String value) {
  if (value == 'null') return null;
  if (value == 'true') return true;
  if (value == 'false') return false;
  return int.tryParse(value) ?? double.tryParse(value) ?? value;
}

String _resolveAgainstProject(_InfraEnvironment env, String value) {
  if (p.isAbsolute(value)) return p.normalize(value);
  return p.normalize(p.join(env.projectContext.root, value));
}

void _printRuntimeResult(
  _InfraEnvironment env,
  InfraServiceManifest manifest,
  InfraRuntimeResult result,
) {
  if (env.json) return;
  for (final action in result.actions) {
    print('${manifest.id}: $action');
  }
  if (result.stdout.trim().isNotEmpty) print(result.stdout.trim());
  if (result.stderr.trim().isNotEmpty) io.stderr.writeln(result.stderr.trim());
  if (result.exitCode != 0) io.exitCode = result.exitCode;
}

InfraRuntimeResult _combineRuntimeResults(List<InfraRuntimeResult> results) {
  final actions = <String>[];
  final stdout = <String>[];
  final stderr = <String>[];
  var exitCode = 0;
  for (final result in results) {
    actions.addAll(result.actions);
    if (result.stdout.trim().isNotEmpty) stdout.add(result.stdout.trim());
    if (result.stderr.trim().isNotEmpty) stderr.add(result.stderr.trim());
    if (result.exitCode != 0) exitCode = result.exitCode;
  }
  return InfraRuntimeResult(
    actions: actions,
    exitCode: exitCode,
    stdout: stdout.join('\n'),
    stderr: stderr.join('\n'),
  );
}
