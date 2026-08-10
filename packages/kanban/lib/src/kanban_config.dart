import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class TicketTypeConfig {
  final String id;
  final String name;

  /// Optional display color for this type's badge in the TUI. When null or
  /// empty, renderers fall back to their own default for the type.
  final String? color;

  const TicketTypeConfig({required this.id, required this.name, this.color});
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
      ticketTypes: (kanbanYaml['ticket_types'] as YamlList)
          .map(
            (t) => TicketTypeConfig(
              id: t['id'] as String,
              name: t['name'] as String,
              color: t['color'] as String?,
            ),
          )
          .toList(),
      columns: (kanbanYaml['columns'] as YamlList)
          .map(
            (c) => ColumnConfig(
              id: c['id'] as String,
              name: c['name'] as String,
              color: c['color'] as String,
              allowedTransitions:
                  (c['allowed_transitions'] as YamlList?)
                      ?.map((t) => t as String)
                      .toList() ??
                  const [],
            ),
          )
          .toList(),
    );
  }

  /// Best-effort variant of [kanban] that returns `null` instead of throwing
  /// when the kanban section is missing or malformed.
  KanbanConfig? get kanbanOrNull {
    try {
      return kanban;
    } catch (_) {
      return null;
    }
  }
}

/// The config-driven value lists a command can advertise.
class ConfiguredIds {
  final List<String> ticketTypes;
  final List<String> columns;

  const ConfiguredIds({this.ticketTypes = const [], this.columns = const []});
}

/// Ticket type and column IDs declared by the nearest project config.
///
/// Returns empty lists when there is no project or its config is unreadable,
/// so callers can fall back to a generic description. Never throws: this feeds
/// `--help` output and MCP tool schemas, which must render regardless.
ConfiguredIds configuredIds({FileSystem fs = const LocalFileSystem()}) {
  final kanban = ProjectContext.findSync(fs: fs)?.config.kanbanOrNull;
  if (kanban == null) return const ConfiguredIds();
  return ConfiguredIds(
    ticketTypes: kanban.ticketTypes.map((t) => t.id).toList(),
    columns: kanban.columns.map((c) => c.id).toList(),
  );
}

/// Usage footer listing the requested config-driven values, or `null` when
/// there are none to report (no project, or an unreadable config).
String? configuredUsageFooter({
  FileSystem fs = const LocalFileSystem(),
  bool ticketTypes = false,
  bool columns = false,
}) {
  final ids = configuredIds(fs: fs);
  final lines = <String>[
    if (ticketTypes && ids.ticketTypes.isNotEmpty)
      'Configured ticket types: ${ids.ticketTypes.join(', ')}',
    if (columns && ids.columns.isNotEmpty)
      'Configured columns: ${ids.columns.join(', ')}',
  ];
  if (lines.isEmpty) return null;
  return '\n${lines.join('\n')}';
}

/// Returns [schema] with the `type` and/or `column` properties constrained to
/// the configured values, so MCP clients can discover them instead of guessing.
///
/// Properties are left untouched when the corresponding list is empty or the
/// schema has no such property.
Map<String, dynamic> withConfiguredEnums(
  Map<String, dynamic> schema, {
  FileSystem fs = const LocalFileSystem(),
  bool ticketTypes = false,
  bool columns = false,
}) {
  final ids = configuredIds(fs: fs);
  var result = schema;
  if (ticketTypes) result = _withEnum(result, 'type', ids.ticketTypes);
  if (columns) result = _withEnum(result, 'column', ids.columns);
  return result;
}

Map<String, dynamic> _withEnum(
  Map<String, dynamic> schema,
  String property,
  List<String> values,
) {
  if (values.isEmpty) return schema;
  final properties = (schema['properties'] as Map?)?.cast<String, dynamic>();
  final prop = (properties?[property] as Map?)?.cast<String, dynamic>();
  if (properties == null || prop == null) return schema;
  return {
    ...schema,
    'properties': {
      ...properties,
      property: {...prop, 'enum': values},
    },
  };
}

/// Extends [ProjectDirs] with the kanban board directory.
extension KanbanDirs on ProjectDirs {
  /// Absolute path to `.project/kanban/`.
  String get kanban => p.join(project, 'kanban');
}
