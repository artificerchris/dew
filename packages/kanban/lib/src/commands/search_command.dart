import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class SearchCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  SearchCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption(
        'query',
        abbr: 'q',
        mandatory: true,
        help: 'Search query (matches title, body, and comments).',
      )
      ..addOption('column', abbr: 'c', help: 'Restrict search to this column.')
      ..addOption(
        'type',
        abbr: 't',
        help: 'Restrict search to this ticket type.',
      )
      ..addOption('label', help: 'Restrict search to tickets with this label.')
      ..addOption(
        'milestone',
        help: 'Restrict search to tickets in this milestone.',
      )
      ..addFlag(
        'include-archived',
        help: 'Include archived tickets.',
        negatable: false,
      );
  }

  @override
  final String name = 'search';

  @override
  final String description =
      'Search tickets by text across title, body, and comments.';

  @override
  final String toolName = 'kanban_search_tickets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final query = (args['query'] as String).toLowerCase();
    final columnFilter = args['column'] as String?;
    final typeFilter = args['type'] as String?;
    final labelFilter = args['label'] as String?;
    final milestoneFilter = args['milestone'] as String?;
    final includeArchived = args['include-archived'] as bool? ?? false;

    final context = await ProjectContext.find(fs: _fs);
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: context.config.kanban.prefix,
      fs: context.fs,
    );
    var tickets = await store.list(includeArchived: includeArchived);

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
      tickets = tickets
          .where((t) => t.milestones.contains(milestoneFilter))
          .toList();
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
