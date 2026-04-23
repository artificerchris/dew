import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class LinkCommand extends DewCommand with DewToolCommand {
  LinkCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Source ticket ID.')
      ..addOption('target', abbr: 't', mandatory: true, help: 'Target ticket ID to link to.');
  }

  @override
  final String name = 'link';

  @override
  final String description = 'Link two tickets together (e.g. to track dependencies).';

  @override
  final String toolName = 'kanban_link_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final targetId = (args['target'] as String).toUpperCase();

    if (id == targetId) throw ArgumentError('A ticket cannot be linked to itself.');

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );

    await store.linkTickets(id, targetId);
    return 'Linked $id → $targetId.';
  }
}
