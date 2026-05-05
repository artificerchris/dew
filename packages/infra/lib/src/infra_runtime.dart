import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:podman/podman.dart' show PodmanClient;

import 'service_manifest.dart';

/// systemd scope for Quadlet units.
enum InfraScope {
  /// User-level systemd and Podman Quadlet search paths.
  user,

  /// System-level systemd and Podman Quadlet search paths.
  system;

  /// Parses the CLI value.
  static InfraScope parse(String value) => switch (value) {
    'user' => user,
    'system' => system,
    _ => throw ArgumentError('Unknown infra scope "$value".'),
  };
}

/// Process result returned by [InfraProcessRunner].
class InfraProcessResult {
  const InfraProcessResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  /// Process exit code.
  final int exitCode;

  /// Captured stdout.
  final String stdout;

  /// Captured stderr.
  final String stderr;
}

/// Runs local processes for runtime backends.
abstract interface class InfraProcessRunner {
  /// Runs [executable] with [arguments].
  Future<InfraProcessResult> run(String executable, List<String> arguments);
}

/// Local [io.Process.run] implementation.
class LocalInfraProcessRunner implements InfraProcessRunner {
  const LocalInfraProcessRunner();

  @override
  Future<InfraProcessResult> run(
    String executable,
    List<String> arguments,
  ) async {
    final result = await io.Process.run(executable, arguments);
    return InfraProcessResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }
}

/// Result of a runtime operation.
class InfraRuntimeResult {
  const InfraRuntimeResult({
    this.actions = const [],
    this.exitCode = 0,
    this.stdout = '',
    this.stderr = '',
  });

  /// Actions performed or planned.
  final List<String> actions;

  /// Runtime command exit code.
  final int exitCode;

  /// Captured stdout.
  final String stdout;

  /// Captured stderr.
  final String stderr;

  /// Machine-readable result.
  Map<String, Object?> toJson() => {
    'actions': actions,
    'exit_code': exitCode,
    'stdout': stdout,
    'stderr': stderr,
  };
}

/// Runtime backend boundary used by `dew infra`.
abstract interface class ContainerRuntime {
  /// Runtime kind handled by this backend.
  InfraRuntimeKind get kind;

  /// Returns true when the service's runtime files are installed.
  Future<bool> isInstalled(InfraServiceManifest manifest, InfraScope scope);

  /// Installs service runtime files.
  Future<InfraRuntimeResult> install(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  });

  /// Uninstalls service runtime files.
  Future<InfraRuntimeResult> uninstall(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  });

  /// Reloads runtime service discovery.
  Future<InfraRuntimeResult> reload({
    required InfraScope scope,
    required bool dryRun,
  });

  /// Starts the service.
  Future<InfraRuntimeResult> start(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  });

  /// Stops the service.
  Future<InfraRuntimeResult> stop(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  });

  /// Restarts the service.
  Future<InfraRuntimeResult> restart(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  });

  /// Reads service status.
  Future<InfraRuntimeResult> status(
    InfraServiceManifest manifest, {
    required InfraScope scope,
  });

  /// Reads service logs.
  Future<InfraRuntimeResult> logs(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool follow,
    required int lines,
  });

  /// Deletes runtime artifacts.
  Future<InfraRuntimeResult> delete(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool deleteContainer,
    required bool deleteData,
    required bool dryRun,
  });
}

/// Factory for runtime backends.
class ContainerRuntimeRegistry {
  const ContainerRuntimeRegistry(this.runtimes);

  /// Registered runtimes.
  final List<ContainerRuntime> runtimes;

  /// Finds the runtime for [kind].
  ContainerRuntime forKind(InfraRuntimeKind kind) => runtimes.firstWhere(
    (runtime) => runtime.kind == kind,
    orElse: () => throw StateError('No runtime registered for ${kind.id}.'),
  );
}

/// Podman Quadlet backend.
class PodmanQuadletRuntime implements ContainerRuntime {
  PodmanQuadletRuntime({
    this.fs = const LocalFileSystem(),
    this.processRunner = const LocalInfraProcessRunner(),
    Map<String, String>? environment,
    PodmanClient Function()? podmanClientFactory,
  }) : environment = environment ?? io.Platform.environment,
       podmanClientFactory = podmanClientFactory ?? PodmanClient.new;

  /// File system used for Quadlet file operations.
  final FileSystem fs;

  /// Process runner used for systemd, journalctl, and CLI cleanup commands.
  final InfraProcessRunner processRunner;

  /// Environment used for Quadlet search path resolution.
  final Map<String, String> environment;

  /// Podman API client factory reserved for backend operations.
  final PodmanClient Function() podmanClientFactory;

  @override
  InfraRuntimeKind get kind => InfraRuntimeKind.podmanQuadlet;

  /// Creates a Podman API client for future backend operations.
  PodmanClient createPodmanClient() => podmanClientFactory();

  @override
  Future<bool> isInstalled(
    InfraServiceManifest manifest,
    InfraScope scope,
  ) async =>
      await fs.link(_targetContainerPath(manifest, scope)).exists() ||
      await fs.file(_targetContainerPath(manifest, scope)).exists();

  @override
  Future<InfraRuntimeResult> install(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  }) async {
    final actions = <String>[];
    final targetDir = quadletSearchPath(scope, environment: environment);
    final targetFile = _targetContainerPath(manifest, scope);
    await _action(
      actions,
      dryRun,
      'create $targetDir',
      () => fs.directory(targetDir).create(recursive: true),
    );
    await _link(actions, dryRun, manifest.containerFilePath, targetFile);

    final dropinsPath = manifest.dropinsDirPath;
    if (dropinsPath != null && await fs.directory(dropinsPath).exists()) {
      final targetDropins = p.join(targetDir, p.basename(dropinsPath));
      await _action(
        actions,
        dryRun,
        'create $targetDropins',
        () => fs.directory(targetDropins).create(recursive: true),
      );
      await for (final entity in fs.directory(dropinsPath).list()) {
        if (entity is! File || p.extension(entity.path) != '.conf') continue;
        await _link(
          actions,
          dryRun,
          entity.path,
          p.join(targetDropins, p.basename(entity.path)),
        );
      }
    }

    return InfraRuntimeResult(actions: actions);
  }

  @override
  Future<InfraRuntimeResult> uninstall(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  }) async {
    final actions = <String>[];
    await _deletePath(actions, dryRun, _targetContainerPath(manifest, scope));
    final dropinsPath = manifest.dropinsDirPath;
    if (dropinsPath != null) {
      await _deletePath(
        actions,
        dryRun,
        p.join(
          quadletSearchPath(scope, environment: environment),
          p.basename(dropinsPath),
        ),
      );
    }
    return InfraRuntimeResult(actions: actions);
  }

  @override
  Future<InfraRuntimeResult> start(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  }) async => _systemctl(scope, ['start', manifest.unit], dryRun: dryRun);

  @override
  Future<InfraRuntimeResult> stop(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  }) async => _systemctl(scope, ['stop', manifest.unit], dryRun: dryRun);

  @override
  Future<InfraRuntimeResult> restart(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool dryRun,
  }) async => _systemctl(scope, ['restart', manifest.unit], dryRun: dryRun);

  @override
  Future<InfraRuntimeResult> status(
    InfraServiceManifest manifest, {
    required InfraScope scope,
  }) async =>
      _systemctl(scope, ['status', manifest.unit, '--no-pager'], dryRun: false);

  @override
  Future<InfraRuntimeResult> logs(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool follow,
    required int lines,
  }) async {
    final args = [
      if (scope == InfraScope.user) '--user',
      '-u',
      manifest.unit,
      '-n',
      '$lines',
      if (follow) '-f',
    ];
    final action = 'journalctl ${args.join(' ')}';
    final result = await processRunner.run('journalctl', args);
    return InfraRuntimeResult(
      actions: [action],
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }

  @override
  Future<InfraRuntimeResult> delete(
    InfraServiceManifest manifest, {
    required InfraScope scope,
    required bool deleteContainer,
    required bool deleteData,
    required bool dryRun,
  }) async {
    final actions = <String>[];
    final outputs = <String>[];
    final errors = <String>[];
    var exitCode = 0;

    if (deleteContainer) {
      final args = ['rm', '--ignore', '--force', manifest.containerName];
      final action = 'podman ${args.join(' ')}';
      actions.add(action);
      if (!dryRun) {
        final result = await processRunner.run('podman', args);
        exitCode = result.exitCode;
        if (result.stdout.trim().isNotEmpty) outputs.add(result.stdout.trim());
        if (result.stderr.trim().isNotEmpty) errors.add(result.stderr.trim());
      }
    }
    if (deleteData) {
      actions.add('delete data artifacts for ${manifest.id}');
    }
    if (actions.isEmpty) {
      actions.add('no runtime artifacts requested for ${manifest.id}');
    }

    return InfraRuntimeResult(
      actions: actions,
      exitCode: exitCode,
      stdout: outputs.join('\n'),
      stderr: errors.join('\n'),
    );
  }

  @override
  Future<InfraRuntimeResult> reload({
    required InfraScope scope,
    required bool dryRun,
  }) => _systemctl(scope, ['daemon-reload'], dryRun: dryRun);

  String _targetContainerPath(
    InfraServiceManifest manifest,
    InfraScope scope,
  ) => p.join(
    quadletSearchPath(scope, environment: environment),
    p.basename(manifest.containerFile),
  );

  Future<void> _link(
    List<String> actions,
    bool dryRun,
    String source,
    String target,
  ) async {
    await _action(actions, dryRun, 'link $source -> $target', () async {
      await _deleteIfExists(target);
      await fs.link(target).create(source, recursive: true);
    });
  }

  Future<void> _deletePath(
    List<String> actions,
    bool dryRun,
    String target,
  ) async {
    await _action(
      actions,
      dryRun,
      'delete $target',
      () => _deleteIfExists(target),
    );
  }

  Future<void> _deleteIfExists(String target) async {
    final type = await fs.type(target, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.directory) {
      await fs.directory(target).delete(recursive: true);
    } else if (type == FileSystemEntityType.link) {
      await fs.link(target).delete();
    } else {
      await fs.file(target).delete();
    }
  }

  Future<void> _action(
    List<String> actions,
    bool dryRun,
    String description,
    Future<void> Function() apply,
  ) async {
    actions.add(description);
    if (!dryRun) await apply();
  }

  Future<InfraRuntimeResult> _systemctl(
    InfraScope scope,
    List<String> arguments, {
    required bool dryRun,
  }) async {
    final args = [if (scope == InfraScope.user) '--user', ...arguments];
    final action = 'systemctl ${args.join(' ')}';
    if (dryRun) return InfraRuntimeResult(actions: [action]);
    final result = await processRunner.run('systemctl', args);
    return InfraRuntimeResult(
      actions: [action],
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}

/// Resolves the Quadlet search path for [scope].
String quadletSearchPath(
  InfraScope scope, {
  Map<String, String> environment = const {},
}) {
  if (scope == InfraScope.system) return '/etc/containers/systemd';
  final xdgConfigHome = environment['XDG_CONFIG_HOME'];
  if (xdgConfigHome != null && xdgConfigHome.isNotEmpty) {
    return p.join(xdgConfigHome, 'containers', 'systemd');
  }
  final home = environment['HOME'] ?? environment['USERPROFILE'] ?? '';
  return p.join(home.isEmpty ? '~' : home, '.config', 'containers', 'systemd');
}
