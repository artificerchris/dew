import 'dart:convert';
import 'dart:io' as io;

import 'package:dew_core/dew_core.dart';
import 'package:dew_infra/dew_infra.dart';
import 'package:file/memory.dart';
import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  group('Infra command registration', () {
    test('registerCommands adds infra command', () {
      final registry = CommandRegistry();
      registerCommands(registry);

      expect(
        registry.commands.map((command) => command.name),
        contains('infra'),
      );
    });

    test('infra command exposes core subcommands', () {
      final command = InfraCommand();

      expect(
        command.subcommands.keys,
        containsAll([
          'list',
          'show',
          'validate',
          'configure',
          'init',
          'install',
          'uninstall',
          'up',
          'down',
          'restart',
          'status',
          'logs',
          'delete',
        ]),
      );
    });
  });

  group('InfraRepository', () {
    test('discovers service manifests', () async {
      final fs = MemoryFileSystem.test();
      _writeService(fs, includeNetwork: true);

      final repository = InfraRepository(
        infraDir: '/project/.project/infrastructure',
        fs: fs,
      );

      final manifests = await repository.list();
      expect(manifests, hasLength(1));
      expect(manifests.single.id, 'postgres');
      expect(manifests.single.runtime, InfraRuntimeKind.podmanQuadlet);
      expect(manifests.single.units, [
        'app_postgres.service',
        'app_postgres-network.service',
      ]);
      expect(
        manifests.single.quadlets.map((quadlet) => quadlet.filePath),
        containsAll([
          '/project/.project/infrastructure/services/postgres/app_postgres.container',
          '/project/.project/infrastructure/services/postgres/app_postgres.network',
        ]),
      );
    });
  });

  group('InfraValidator', () {
    test('accepts a complete service manifest', () async {
      final fs = MemoryFileSystem.test();
      _writeService(fs);
      final manifest = await InfraRepository(
        infraDir: '/project/.project/infrastructure',
        fs: fs,
      ).get('postgres');

      final issues = await InfraValidator(fs: fs).validate(manifest);

      expect(issues, isEmpty);
    });

    test('reports service id and invalid quadlet units', () async {
      final fs = MemoryFileSystem.test();
      _writeService(fs, serviceId: 'wrong', unit: 'wrong');
      final manifest =
          await InfraRepository(
            infraDir: '/project/.project/infrastructure',
            fs: fs,
          ).loadFromManifestPath(
            '/project/.project/infrastructure/services/postgres/manifest.yaml',
            serviceDir: '/project/.project/infrastructure/services/postgres',
          );

      final issues = await InfraValidator(fs: fs).validate(manifest);

      expect(
        issues.map((issue) => issue.message).join('\n'),
        contains('must match directory'),
      );
      expect(
        issues.map((issue) => issue.message).join('\n'),
        contains('must end with .service'),
      );
    });
  });

  group('PodmanQuadletRuntime', () {
    test(
      'install dry-run reports symlink actions without writing files',
      () async {
        final fs = MemoryFileSystem.test();
        _writeService(fs, includeNetwork: true, includeFile: true);
        final manifest = await InfraRepository(
          infraDir: '/project/.project/infrastructure',
          fs: fs,
        ).get('postgres');
        final runtime = PodmanQuadletRuntime(
          fs: fs,
          environment: const {'HOME': '/home/test'},
        );

        final result = await runtime.install(
          manifest,
          scope: InfraScope.user,
          dryRun: true,
        );

        expect(result.actions.join('\n'), contains('app_postgres.container'));
        expect(result.actions.join('\n'), contains('app_postgres.network'));
        expect(result.actions.join('\n'), contains('Containerfile'));
        expect(
          await fs
              .link(
                '/home/test/.config/containers/systemd/app_postgres.container',
              )
              .exists(),
          isFalse,
        );
      },
    );

    test('quadletSearchPath respects user and system scope', () {
      expect(
        quadletSearchPath(
          InfraScope.user,
          environment: const {'XDG_CONFIG_HOME': '/config'},
        ),
        '/config/containers/systemd',
      );
      expect(quadletSearchPath(InfraScope.system), '/etc/containers/systemd');
    });
  });

  group('service-manifest.schema.json', () {
    test('validates the manifest contract shape', () {
      final schema = JsonSchema.create(
        jsonDecode(_schemaFile().readAsStringSync()),
      );

      final result = schema.validate(_manifestObject());

      expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    });
  });
}

void _writeService(
  MemoryFileSystem fs, {
  String serviceId = 'postgres',
  String unit = 'app_postgres.service',
  bool includeNetwork = false,
  bool includeFile = false,
}) {
  final serviceDir = fs.directory(
    '/project/.project/infrastructure/services/postgres',
  )..createSync(recursive: true);
  fs.directory('${serviceDir.path}/app_postgres.container.d').createSync();
  fs.directory('${serviceDir.path}/app_postgres.profiles.d').createSync();
  fs
      .file('${serviceDir.path}/app_postgres.container')
      .writeAsStringSync('[Container]\nImage=postgres:16\n');
  if (includeNetwork) {
    fs
        .file('${serviceDir.path}/app_postgres.network')
        .writeAsStringSync('[Network]\nNetworkName=app_postgres\n');
  }
  if (includeFile) {
    fs
        .file('${serviceDir.path}/Containerfile')
        .writeAsStringSync('FROM scratch\n');
  }
  fs
      .file('${serviceDir.path}/configure.schema.json')
      .writeAsStringSync('{"type":"object"}');
  fs
      .file('${serviceDir.path}/init.schema.json')
      .writeAsStringSync('{"type":"object"}');
  final networkQuadlet = includeNetwork
      ? '''
  - file: app_postgres.network
'''
      : '';
  final files = includeFile
      ? '''
files:
  - Containerfile

'''
      : '';
  fs.file('${serviceDir.path}/manifest.yaml').writeAsStringSync('''
id: $serviceId
name: PostgreSQL

runtime:
  type: podman-quadlet

quadlets:
  - file: app_postgres.container
    unit: $unit
    container_name: app_postgres
    dropins_dir: app_postgres.container.d
    profiles_dir: app_postgres.profiles.d
$networkQuadlet

$files
schemas:
  configure: configure.schema.json
  init: init.schema.json
''');
}

Map<String, Object?> _manifestObject() => {
  'id': 'postgres',
  'name': 'PostgreSQL',
  'runtime': {'type': 'podman-quadlet'},
  'quadlets': [
    {
      'file': 'app_postgres.container',
      'unit': 'app_postgres.service',
      'container_name': 'app_postgres',
      'dropins_dir': 'app_postgres.container.d',
      'profiles_dir': 'app_postgres.profiles.d',
    },
    {'file': 'app_postgres.network'},
  ],
  'files': ['Containerfile'],
  'schemas': {'configure': 'configure.schema.json', 'init': 'init.schema.json'},
};

io.File _schemaFile() {
  for (final path in [
    'packages/infra/schemas/service-manifest.schema.json',
    'schemas/service-manifest.schema.json',
  ]) {
    final file = io.File(path);
    if (file.existsSync()) return file;
  }
  throw StateError('Could not find service-manifest.schema.json.');
}
