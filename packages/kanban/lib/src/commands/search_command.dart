import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class SearchCommand extends DewCommand with DewToolCommand {
  SearchCommand() {
    argParser
      ..addOption(
        'query',
        abbr: 'q',
        mandatory: true,
        help: 'Search query (matches title, body, and comments).',
      )
      ..addOption('column', abbr: 'c', help: 'Restrict search to this column.')
      ..addOption('type', abbr: 't', help: 'Restrict search to this ticket type.');
  }

  @override
  final String name = 'search';

  @override
  final String description = 'Search tickets by text across title, body, and comments.';

  @override
  final String toolName = 'kanban_search_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final query = (args['query'] as String).toLowerCase();
    final columnFilter = args['column'] as String?;
    final typeFilter = args['type'] as String?;

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

    final matches = tickets.where((t) {
      return t.title.toLowerCase().contains(query) ||
          t.body.toLowerCase().contains(query) ||
          t.comments.any((c) => c.toLowerCase().contains(query));
    }).toList();

    if (matches.isEmpty) return 'No tickets found matching "$query".';
    return matches
        .map((t) => '[${t.id}] (${t.type}) [${t.column}] ${t.title}')
        .join('\n');
  }
}
