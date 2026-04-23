import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class UpdateCommand extends DewCommand {
  UpdateCommand() {
    argParser
      ..addOption('title', abbr: 't', help: 'New title.')
      ..addOption('type', help: 'New ticket type.')
      ..addOption('column', abbr: 'c', help: 'New column.')
      ..addOption('body', abbr: 'b', help: 'New body (replaces existing).');
  }

  @override
  final String name = 'update';

  @override
  final String description = 'Update a kanban ticket.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) usageException('Ticket ID is required.');
    final id = rest.first.toUpperCase();

    final title = argResults!['title'] as String?;
    final typeId = argResults!['type'] as String?;
    final column = argResults!['column'] as String?;
    final body = argResults!['body'] as String?;

    if (title == null && typeId == null && column == null && body == null) {
      usageException('At least one option must be specified.');
    }

    final context = await ProjectContext.find();
    final config = context.config.kanban;

    if (typeId != null && !config.ticketTypes.any((t) => t.id == typeId)) {
      usageException(
        'Unknown type "$typeId". '
        'Valid types: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }

    if (column != null && !config.columns.any((c) => c.id == column)) {
      usageException(
        'Unknown column "$column". '
        'Valid columns: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );

    try {
      final ticket = await store.update(
        id,
        title: title,
        type: typeId,
        column: column,
        body: body,
      );
      print('Updated ${ticket.id}.');
    } on ArgumentError catch (e) {
      usageException(e.message as String);
    }
  }
}
