import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class UpdateCommand extends DewCommand with DewToolCommand {
  UpdateCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID.')
      ..addOption('title', abbr: 't', help: 'New title.')
      ..addOption('type', help: 'New ticket type.')
      ..addOption('column', abbr: 'c', help: 'New column.')
      ..addOption('body', abbr: 'b', help: 'New body (replaces existing body).');
  }

  @override
  final String name = 'update';

  @override
  final String description = 'Update one or more fields on an existing kanban ticket.';

  @override
  final String toolName = 'kanban_update_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final title = args['title'] as String?;
    final typeId = args['type'] as String?;
    final column = args['column'] as String?;
    final body = args['body'] as String?;

    if (title == null && typeId == null && column == null && body == null) {
      throw ArgumentError('At least one of --title, --type, --column, --body must be specified.');
    }

    final context = await ProjectContext.find();
    final config = context.config.kanban;

    if (typeId != null && !config.ticketTypes.any((t) => t.id == typeId)) {
      throw ArgumentError(
        'Unknown type "$typeId". '
        'Valid: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }
    if (column != null && !config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );
    final ticket = await store.update(id, title: title, type: typeId, column: column, body: body);
    return 'Updated ${ticket.id}.';
  }
}
