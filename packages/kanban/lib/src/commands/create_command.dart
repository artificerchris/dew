import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class CreateCommand extends DewCommand {
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
  Future<void> run() async {
    final context = await ProjectContext.find();
    final config = context.config.kanban;

    final title = argResults!['title'] as String;
    final typeId = argResults!['type'] as String;
    final columnArg = argResults!['column'] as String?;
    final body = argResults!['body'] as String? ?? '';

    if (!config.ticketTypes.any((t) => t.id == typeId)) {
      usageException(
        'Unknown type "$typeId". '
        'Valid types: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }

    final column = columnArg ?? config.columns.first.id;
    if (!config.columns.any((c) => c.id == column)) {
      usageException(
        'Unknown column "$column". '
        'Valid columns: ${config.columns.map((c) => c.id).join(', ')}',
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

    print('Created ${ticket.id}.');
  }
}
