import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class UnlinkCommand extends DewCommand with DewToolCommand {
  UnlinkCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Source ticket ID.')
      ..addOption('target', abbr: 't', mandatory: true, help: 'Target ticket ID to remove link to.');
  }

  @override
  final String name = 'unlink';

  @override
  final String description = 'Remove a link between two tickets.';

  @override
  final String toolName = 'kanban_unlink_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final targetId = (args['target'] as String).toUpperCase();

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );

    await store.unlinkTickets(id, targetId);
    return 'Unlinked $id → $targetId.';
  }
}
