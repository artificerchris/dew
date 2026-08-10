import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class CreateCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  CreateCommand({this._fs = const LocalFileSystem()}) {
    argParser
      ..addOption('title', abbr: 't', mandatory: true, help: 'Ticket title.')
      ..addOption(
        'type',
        mandatory: true,
        help: 'Ticket type. Must be one of the configured ticket_types.',
      )
      ..addOption(
        'column',
        abbr: 'c',
        help: 'Initial column. Defaults to the first configured column.',
      )
      ..addOption('body', abbr: 'b', help: 'Ticket description.')
      ..addMultiOption(
        'milestone',
        help: 'Milestone(s) to assign (repeatable).',
      )
      ..addMultiOption('label', help: 'Label(s) to assign (repeatable).');
  }

  @override
  final String name = 'create';

  @override
  final String description = 'Create a new kanban ticket.';

  @override
  final String toolName = 'kanban_create_ticket';

  @override
  String? get usageFooter =>
      configuredUsageFooter(fs: _fs, ticketTypes: true, columns: true);

  @override
  Map<String, dynamic> get toolInputSchema => withConfiguredEnums(
    super.toolInputSchema,
    fs: _fs,
    ticketTypes: true,
    columns: true,
  );

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;

    final title = '${args['title']}';
    final typeId = '${args['type']}';
    final columnArg = args['column'] != null ? '${args['column']}' : null;
    final body = args['body'] != null ? '${args['body']}' : '';
    final milestones = _toStringList(args['milestone']);
    final labels = _toStringList(args['label']);

    if (!config.ticketTypes.any((t) => t.id == typeId)) {
      throw ArgumentError(
        'Unknown type "$typeId". '
        'Valid: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }

    final column = columnArg ?? config.columns.first.id;
    if (!config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: config.prefix,
      fs: context.fs,
    );
    final ticket = await store.create(
      title: title,
      type: typeId,
      column: column,
      body: body,
      milestones: milestones,
      labels: labels,
    );
    return 'Created ${ticket.id}: ${ticket.title}';
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }
}
