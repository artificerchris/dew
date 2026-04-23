import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class GetCommand extends DewCommand {
  @override
  final String name = 'get';

  @override
  final String description = 'Get a kanban ticket by ID.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) usageException('Ticket ID is required.');
    final id = rest.first.toUpperCase();

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );

    final ticket = await store.findById(id);
    if (ticket == null) usageException('Ticket $id not found.');

    print('[${ticket.id}] (${ticket.type}) [${ticket.column}] ${ticket.title}');
    print('Created: ${ticket.created.toLocal().toString().split('.').first}');

    if (ticket.body.isNotEmpty) {
      print('');
      print(ticket.body);
    }

    for (final (i, comment) in ticket.comments.indexed) {
      print('');
      print('── Comment ${i + 1} ${'─' * 20}');
      print(comment);
    }
  }
}
