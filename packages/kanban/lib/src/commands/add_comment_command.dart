import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class AddCommentCommand extends DewCommand with DewToolCommand {
  AddCommentCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID (e.g. DEW-0001).')
      ..addOption('comment', abbr: 'm', mandatory: true, help: 'Comment text to append.');
  }

  @override
  final String name = 'comment';

  @override
  final String description = 'Append a comment to a kanban ticket.';

  @override
  final String toolName = 'kanban_add_comment';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final comment = args['comment'] as String;

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );
    await store.addComment(id, comment);
    return 'Comment added to $id.';
  }
}
