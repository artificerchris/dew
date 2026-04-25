import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class UnlinkCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  UnlinkCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Source ticket ID.')
      ..addOption(
        'target',
        abbr: 't',
        mandatory: true,
        help: 'Target ticket ID to remove link to.',
      );
  }

  @override
  final String name = 'unlink';

  @override
  final String description = 'Remove a link between two tickets.';

  @override
  final String toolName = 'kanban_unlink_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = '${args['id']}'.toUpperCase();
    final targetId = '${args['target']}'.toUpperCase();

    final context = await ProjectContext.find(fs: _fs);
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: context.config.kanban.prefix,
      fs: context.fs,
    );

    await store.unlinkTickets(id, targetId);
    return 'Unlinked $id → $targetId.';
  }
}
