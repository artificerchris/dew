import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class AddCommentCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  AddCommentCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption(
        'id',
        abbr: 'i',
        mandatory: true,
        help: 'Ticket ID (e.g. DEW-0001).',
      )
      ..addOption(
        'comment',
        abbr: 'm',
        mandatory: true,
        help: 'Comment text to append.',
      );
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

    final context = await ProjectContext.find(fs: _fs);
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: context.config.kanban.prefix,
      fs: context.fs,
    );
    await store.addComment(id, comment);
    return 'Comment added to $id.';
  }
}
