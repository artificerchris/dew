import 'package:dew_core/dew_core.dart';
import '../kanban_config.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class ListCommand extends DewCommand with DewToolCommand {
  ListCommand() {
    argParser
      ..addOption('column', abbr: 'c', help: 'Filter to tickets in this column.')
      ..addOption('type', abbr: 't', help: 'Filter to tickets of this type.')
      ..addOption('label', help: 'Filter to tickets with this label.')
      ..addOption('milestone', help: 'Filter to tickets in this milestone.');
  }

  @override
  final String name = 'list';

  @override
  final String description = 'List kanban tickets, optionally filtered by column or type.';

  @override
  final String toolName = 'kanban_list_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final columnFilter = args['column'] as String?;
    final typeFilter = args['type'] as String?;
    final labelFilter = args['label'] as String?;
    final milestoneFilter = args['milestone'] as String?;

    final context = await ProjectContext.find();
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );
    var tickets = await store.list();

    if (columnFilter != null) {
      tickets = tickets.where((t) => t.column == columnFilter).toList();
    }
    if (typeFilter != null) {
      tickets = tickets.where((t) => t.type == typeFilter).toList();
    }
    if (labelFilter != null) {
      tickets = tickets.where((t) => t.labels.contains(labelFilter)).toList();
    }
    if (milestoneFilter != null) {
      tickets = tickets.where((t) => t.milestones.contains(milestoneFilter)).toList();
    }

    if (tickets.isEmpty) return 'No tickets found.';
    return tickets
        .map((t) => '[${t.id}] (${t.type}) [${t.column}] ${t.title}')
        .join('\n');
  }
}
