import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Thin wrapper around the raw project YAML.
///
/// Feature packages extend this class via Dart extension methods to expose
/// typed configuration (e.g. [KanbanDewConfig.kanban], [McpDewConfig.mcp]).
/// This keeps feature-specific config classes out of core.
class DewConfig {
  final YamlMap raw;

  const DewConfig({required this.raw});

  factory DewConfig.fromYaml(YamlMap yaml) => DewConfig(raw: yaml);
}

/// Locates the nearest project root and exposes the parsed [DewConfig].
class ProjectContext {
  final String root;
  final DewConfig config;

  const ProjectContext({required this.root, required this.config});

  /// Walks up from [Directory.current] until a `.project/dew.yaml` is found.
  static Future<ProjectContext> find() async {
    var dir = Directory.current;
    while (true) {
      final configFile = File(p.join(dir.path, '.project', 'dew.yaml'));
      if (await configFile.exists()) {
        final yaml = loadYaml(await configFile.readAsString()) as YamlMap;
        return ProjectContext(
          root: dir.path,
          config: DewConfig.fromYaml(yaml),
        );
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError(
          'Could not find .project/dew.yaml. '
          'Run "dew init ." to initialise a project here.',
        );
      }
      dir = parent;
    }
  }
}
