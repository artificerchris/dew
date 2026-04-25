import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class MoveCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  MoveCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID.')
      ..addOption(
        'column',
        abbr: 'c',
        mandatory: true,
        help: 'Target column ID.',
      );
  }

  @override
  final String name = 'move';

  @override
  final String description =
      'Move a ticket to a different column (validates against config).';

  @override
  final String toolName = 'kanban_move_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final column = args['column'] as String;

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;

    if (!config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: config.prefix,
      fs: context.fs,
    );

    final ticket = await store.findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');

    // Check allowed_transitions if configured on the current column.
    final currentColConfig = config.columns.firstWhere(
      (c) => c.id == ticket.column,
      orElse: () =>
          ColumnConfig(id: ticket.column, name: ticket.column, color: ''),
    );
    if (currentColConfig.allowedTransitions.isNotEmpty &&
        !currentColConfig.allowedTransitions.contains(column)) {
      throw ArgumentError(
        'Column "${ticket.column}" does not allow transitions to "$column". '
        'Allowed: ${currentColConfig.allowedTransitions.join(', ')}',
      );
    }

    final updated = await store.update(id, column: column);
    return 'Moved ${updated.id} to "$column".';
  }
}
