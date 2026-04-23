import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class MoveCommand extends DewCommand with DewToolCommand {
  MoveCommand() {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID.')
      ..addOption('column', abbr: 'c', mandatory: true, help: 'Target column ID.');
  }

  @override
  final String name = 'move';

  @override
  final String description = 'Move a ticket to a different column (validates against config).';

  @override
  final String toolName = 'kanban_move_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final column = args['column'] as String;

    final context = await ProjectContext.find();
    final config = context.config.kanban;

    if (!config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );

    final ticket = await store.update(id, column: column);
    return 'Moved ${ticket.id} to "$column".';
  }
}
