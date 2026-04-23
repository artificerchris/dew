import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class TicketTypeConfig {
  final String id;
  final String name;

  const TicketTypeConfig({required this.id, required this.name});
}

class ColumnConfig {
  final String id;
  final String name;
  final String color;

  const ColumnConfig({
    required this.id,
    required this.name,
    required this.color,
  });
}

class KanbanConfig {
  final String prefix;
  final List<TicketTypeConfig> ticketTypes;
  final List<ColumnConfig> columns;

  const KanbanConfig({
    required this.prefix,
    required this.ticketTypes,
    required this.columns,
  });
}

class McpConfig {
  final String host;
  final int port;

  const McpConfig({required this.host, required this.port});
}

class DewConfig {
  final KanbanConfig kanban;
  final McpConfig mcp;

  const DewConfig({required this.kanban, required this.mcp});

  factory DewConfig.fromYaml(YamlMap yaml) {
    final dew = yaml['dew'] as YamlMap;

    final mcpYaml = dew['mcp'] as YamlMap;
    final mcp = McpConfig(
      host: mcpYaml['host'] as String,
      port: mcpYaml['port'] as int,
    );

    final kanbanYaml = dew['kanban'] as YamlMap;
    final ticketTypes =
        (kanbanYaml['ticket_types'] as YamlList)
            .map(
              (t) => TicketTypeConfig(
                id: t['id'] as String,
                name: t['name'] as String,
              ),
            )
            .toList();
    final columns =
        (kanbanYaml['columns'] as YamlList)
            .map(
              (c) => ColumnConfig(
                id: c['id'] as String,
                name: c['name'] as String,
                color: c['color'] as String,
              ),
            )
            .toList();

    return DewConfig(
      kanban: KanbanConfig(
        prefix: kanbanYaml['prefix'] as String,
        ticketTypes: ticketTypes,
        columns: columns,
      ),
      mcp: mcp,
    );
  }
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
