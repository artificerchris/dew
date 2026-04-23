import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class DeleteCommand extends DewCommand {
  @override
  final String name = 'delete';

  @override
  final String description = 'Delete a kanban ticket.';

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

    try {
      await store.delete(id);
      print('Deleted $id.');
    } on ArgumentError catch (e) {
      usageException(e.message as String);
    }
  }
}
