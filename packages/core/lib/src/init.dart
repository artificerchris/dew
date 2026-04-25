import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';

/// Options passed to every [DewInitHook] during `dew init`.
class DewInitOptions {
  /// Whether to create `.gitkeep` files in newly-created empty directories.
  final bool gitkeep;

  const DewInitOptions({this.gitkeep = true});
}

/// Creates the initial `.project/` scaffold for `dew init`.
///
/// Each module (kanban, mcp, etc.) registers a hook so it can create its own
/// subdirectories and config alongside the core scaffold.
abstract interface class DewInitHook {
  /// Called after `dew.yaml` is written. [projectRoot] is the resolved absolute
  /// path of the project being initialised; [config] is the loaded config;
  /// [options] carries flags like [DewInitOptions.gitkeep].
  Future<void> onInit(
    String projectRoot,
    DewConfig config,
    DewInitOptions options,
  );
}

const _defaultDewYaml = '''
dew:
  mcp:
    host: "localhost"
    port: 8080

  kanban:
    prefix: "PROJ"
    ticket_types:
      - id: "epic"
        name: "Epic"
      - id: "story"
        name: "Story"
      - id: "task"
        name: "Task"
      - id: "bug"
        name: "Bug"
      - id: "spike"
        name: "Spike"
    columns:
      - id: "backlog"
        name: "Backlog"
        color: "blue"
      - id: "doing"
        name: "Doing"
        color: "yellow"
      - id: "done"
        name: "Done"
        color: "green"
''';

class InitCommand extends Command<void> {
  final List<DewInitHook> _hooks;
  final FileSystem _fs;

  InitCommand(this._hooks, {FileSystem fs = const LocalFileSystem()})
    : _fs = fs {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the project root to initialise.',
        defaultsTo: '.',
      )
      ..addFlag(
        'gitkeep',
        help: 'Add .gitkeep files to newly-created empty directories.',
        defaultsTo: true,
      );
  }

  @override
  final String name = 'init';

  @override
  final String description =
      'Initialise a Dew project at the given path, creating '
      '.project/dew.yaml and scaffolding module directories.';

  @override
  Future<void> run() async {
    final rawPath = argResults!['path'] as String;
    final gitkeep = argResults!['gitkeep'] as bool;
    final projectRoot = p.canonicalize(rawPath);
    final options = DewInitOptions(gitkeep: gitkeep);

    final projectDir = _fs.directory(p.join(projectRoot, '.project'));
    final configFile = _fs.file(p.join(projectDir.path, 'dew.yaml'));

    await projectDir.create(recursive: true);

    if (await configFile.exists()) {
      print('  found   .project/dew.yaml (already exists, skipping)');
    } else {
      await configFile.writeAsString(_defaultDewYaml.trimLeft());
      print('  created .project/dew.yaml');
    }

    final config = DewConfig.fromYaml(
      loadYaml(await configFile.readAsString()) as YamlMap,
    );

    for (final hook in _hooks) {
      await hook.onInit(projectRoot, config, options);
    }

    print('\nProject initialised at $projectRoot');
  }
}
