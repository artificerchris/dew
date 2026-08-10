import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class DeleteCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  DeleteCommand({this._fs = const LocalFileSystem()}) {
    argParser.addOption(
      'id',
      abbr: 'i',
      mandatory: true,
      help: 'Ticket ID (e.g. DEW-0001).',
    );
  }

  @override
  final String name = 'delete';

  @override
  final String description = 'Delete a kanban ticket.';

  @override
  final String toolName = 'kanban_delete_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = '${args['id']}'.toUpperCase();
    final context = await ProjectContext.find(fs: _fs);
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: context.config.kanban.prefix,
      fs: context.fs,
    );
    await store.delete(id);
    return 'Deleted $id.';
  }
}
