import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class CreateCommand extends DewCommand with DewToolCommand {
  CreateCommand() {
    argParser
      ..addOption('title', abbr: 't', mandatory: true, help: 'Ticket title.')
      ..addOption(
        'type',
        mandatory: true,
        help: 'Ticket type (e.g. task, bug).',
      )
      ..addOption(
        'column',
        abbr: 'c',
        help: 'Initial column. Defaults to the first configured column.',
      )
      ..addOption('body', abbr: 'b', help: 'Ticket description.');
  }

  @override
  final String name = 'create';

  @override
  final String description = 'Create a new kanban ticket.';

  @override
  final String toolName = 'kanban_create_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final context = await ProjectContext.find();
    final config = context.config.kanban;

    final title = args['title'] as String;
    final typeId = args['type'] as String;
    final columnArg = args['column'] as String?;
    final body = args['body'] as String? ?? '';

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
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );
    final ticket = await store.create(
      title: title,
      type: typeId,
      column: column,
      body: body,
    );
    return 'Created ${ticket.id}: ${ticket.title}';
  }
}
