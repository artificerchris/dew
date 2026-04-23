import 'package:dew_core/dew_core.dart';
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

  const ColumnConfig({required this.id, required this.name, required this.color});
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
                ),
              )
              .toList(),
    );
  }
}
