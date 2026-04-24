import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class UnarchiveCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  UnarchiveCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID to unarchive.')
      ..addOption(
        'column',
        abbr: 'c',
        help: 'Column to restore to. Defaults to the first configured column.',
      );
  }

  @override
  final String name = 'unarchive';

  @override
  final String description = 'Restore an archived ticket to a column.';

  @override
  final String toolName = 'kanban_unarchive_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;
    final kanbanDir = p.join(context.root, '.project', 'kanban');

    final store = TicketStore(kanbanDir: kanbanDir, prefix: config.prefix, fs: context.fs);
    final ticket = await store.findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    if (ticket.column != 'archive') return '$id is not archived.';

    final columnArg = args['column'] as String?;
    final targetColumn = columnArg ?? config.columns.first.id;
    if (!config.columns.any((c) => c.id == targetColumn)) {
      throw ArgumentError(
        'Unknown column "$targetColumn". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final targetDir = context.fs.directory(p.join(kanbanDir, targetColumn));
    await targetDir.create(recursive: true);

    final srcFile = context.fs.file(p.join(kanbanDir, 'archive', '$id.md'));
    final dstFile = context.fs.file(p.join(targetDir.path, '$id.md'));
    await srcFile.rename(dstFile.path);

    return 'Restored $id to "$targetColumn".';
  }
}
