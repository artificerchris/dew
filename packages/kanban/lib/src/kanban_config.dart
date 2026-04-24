import 'package:dew_core/dew_core.dart';
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

  /// Optional list of column IDs that this column can transition to.
  /// If null/empty, all transitions are allowed.
  final List<String> allowedTransitions;

  const ColumnConfig({
    required this.id,
    required this.name,
    required this.color,
    this.allowedTransitions = const [],
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

extension KanbanDewConfig on DewConfig {
  KanbanConfig get kanban {
    final kanbanYaml = (raw['dew'] as YamlMap)['kanban'] as YamlMap;
    return KanbanConfig(
      prefix: kanbanYaml['prefix'] as String,
      ticketTypes:
          (kanbanYaml['ticket_types'] as YamlList)
              .map((t) => TicketTypeConfig(id: t['id'] as String, name: t['name'] as String))
              .toList(),
      columns:
          (kanbanYaml['columns'] as YamlList)
              .map(
                (c) => ColumnConfig(
                  id: c['id'] as String,
                  name: c['name'] as String,
                  color: c['color'] as String,
                  allowedTransitions: (c['allowed_transitions'] as YamlList?)
                          ?.map((t) => t as String)
                          .toList() ??
                      const [],
                ),
              )
              .toList(),
    );
  }
}

/// Extends [ProjectDirs] with the kanban board directory.
extension KanbanDirs on ProjectDirs {
  /// Absolute path to `.project/kanban/`.
  String get kanban => p.join(project, 'kanban');
}
