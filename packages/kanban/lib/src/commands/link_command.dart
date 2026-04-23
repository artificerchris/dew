import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket.dart';
import '../ticket_store.dart';

class LinkCommand extends DewCommand with DewToolCommand {
  LinkCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Source ticket ID.')
      ..addOption('target', abbr: 't', mandatory: true, help: 'Target ticket ID.')
      ..addOption(
        'type',
        abbr: 'y',
        mandatory: true,
        allowed: linkTypeInverses.keys.toList(),
        help: 'Relationship type (e.g. blocks, relates_to, parent_of).',
      );
  }

  @override
  final String name = 'link';

  @override
  final String description =
      'Link two tickets with a typed relationship. '
      'The inverse link is automatically added to the target ticket.';

  @override
  final String toolName = 'kanban_link_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final targetId = (args['target'] as String).toUpperCase();
    final type = args['type'] as String;

    if (id == targetId) throw ArgumentError('A ticket cannot be linked to itself.');

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );

    await store.linkTickets(id, targetId, type);
    final inverse = linkTypeInverses[type]!;
    return 'Linked $id –[$type]→ $targetId (and $targetId –[$inverse]→ $id).';
  }
}
