import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
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

/// Path helper for well-known directories under a project root.
///
/// Feature packages extend this via extension methods to expose their own
/// directories (e.g. [KanbanDirs.kanban]).
class ProjectDirs {
  final String _root;
  const ProjectDirs(this._root);

  /// The workspace root (where `.project/` lives).
  String get workspace => _root;

  /// `.project/` directory.
  String get project => p.join(_root, '.project');
}

/// Locates the nearest project root and exposes the parsed [DewConfig].
class ProjectContext {
  final String root;
  final DewConfig config;
  final FileSystem fs;
  final String configFilePath;

  const ProjectContext({
    required this.root,
    required this.config,
    required this.fs,
    required this.configFilePath,
  });

  /// Typed path helpers for this project's well-known directories.
  ProjectDirs get dirs => ProjectDirs(root);

  /// Path to `.project/dew.yaml` used to bootstrap this context.
  String get configPath => configFilePath;

  /// Resolves configuration values that are file paths relative to this project's
  /// `.project/dew.yaml` location.
  String resolveConfigPath(String value) {
    final expanded = _expandTilde(value);
    if (p.isAbsolute(expanded)) return p.normalize(expanded);
    final segments = p.split(p.normalize(expanded));
    if (segments.isNotEmpty && segments.first == '.project') {
      return p.normalize(
        p.joinAll(
          [
            p.dirname(configPath),
            '..',
            '.project',
            ...segments.skip(1),
          ],
        ),
      );
    }
    return p.normalize(p.join(p.dirname(configPath), expanded));
  }

  /// Walks up from [from] (defaults to [fs.currentDirectory]) until a
  /// `.project/dew.yaml` is found.
  static Future<ProjectContext> find({
    FileSystem fs = const LocalFileSystem(),
    Directory? from,
  }) async {
    var dir = from ?? fs.currentDirectory;
    while (true) {
      final configFile = fs.file(p.join(dir.path, '.project', 'dew.yaml'));
      if (await configFile.exists()) {
        final path = configFile.path;
        final yaml = loadYaml(await configFile.readAsString()) as YamlMap;
        return ProjectContext(
          root: dir.path,
          config: DewConfig.fromYaml(yaml),
          fs: fs,
          configFilePath: path,
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

  /// Synchronous, non-throwing variant of [find]. Returns `null` when no
  /// project is found or its config cannot be parsed.
  ///
  /// Exists for callers that need config outside an async boundary and must
  /// degrade gracefully — CLI usage text and MCP tool schemas are built before
  /// (or without) a project context, and neither may fail on a broken config.
  static ProjectContext? findSync({
    FileSystem fs = const LocalFileSystem(),
    Directory? from,
  }) {
    var dir = from ?? fs.currentDirectory;
    while (true) {
      final configFile = fs.file(p.join(dir.path, '.project', 'dew.yaml'));
      if (configFile.existsSync()) {
        try {
          final yaml = loadYaml(configFile.readAsStringSync());
          if (yaml is! YamlMap) return null;
          return ProjectContext(
            root: dir.path,
            config: DewConfig.fromYaml(yaml),
            fs: fs,
            configFilePath: configFile.path,
          );
        } catch (_) {
          return null;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }
}

String _expandTilde(String input) {
  if (!input.startsWith('~')) return input;
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  if (home.isEmpty) return input;
  if (input.length == 1) return home;
  final rest = input.substring(1);
  if (rest.startsWith('/')) return p.join(home, rest.substring(1));
  return p.join(home, rest);
}
