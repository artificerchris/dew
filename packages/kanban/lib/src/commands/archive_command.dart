import 'dart:io';

import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class ArchiveCommand extends DewCommand with DewToolCommand {
  ArchiveCommand() {
    argParser.addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID to archive.');
  }

  @override
  final String name = 'archive';

  @override
  final String description = 'Archive a ticket (moves it to the archive column).';

  @override
  final String toolName = 'kanban_archive_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();

    final context = await ProjectContext.find();
    final config = context.config.kanban;
    final kanbanDir = p.join(context.root, '.project', 'kanban');

    final store = TicketStore(kanbanDir: kanbanDir, prefix: config.prefix);
    final ticket = await store.findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    if (ticket.column == 'archive') return '$id is already archived.';

    final archiveDir = Directory(p.join(kanbanDir, 'archive'));
    await archiveDir.create(recursive: true);

    // Move the file directly rather than through update() so we don't write
    // the column back into the ticket frontmatter (it's derived from the dir).
    final srcFile = File(p.join(kanbanDir, ticket.column, '$id.md'));
    final dstFile = File(p.join(archiveDir.path, '$id.md'));
    await srcFile.rename(dstFile.path);

    return 'Archived $id.';
  }
}
