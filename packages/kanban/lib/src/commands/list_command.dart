import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket.dart';
import '../ticket_store.dart';

class ListCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  ListCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('column', abbr: 'c', help: 'Filter to tickets in this column.')
      ..addOption('type', abbr: 't', help: 'Filter to tickets of this type.')
      ..addOption('label', help: 'Filter to tickets with this label.')
      ..addOption('milestone', help: 'Filter to tickets in this milestone.')
      ..addFlag('include-archived', help: 'Include archived tickets.', negatable: false);
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
      tickets = tickets.where((t) => t.milestones.contains(milestoneFilter)).toList();
    }

    if (tickets.isEmpty) return 'No tickets found.';

    // If a column filter is applied, skip the grouping header.
    if (columnFilter != null) {
      return tickets.map((t) => '[${t.id}] (${t.type}) ${t.title}').join('\n');
    }

    // Group by column and emit with headers.
    final byColumn = <String, List<Ticket>>{};
    for (final t in tickets) {
      (byColumn[t.column] ??= []).add(t);
    }
    final buf = StringBuffer();
    var first = true;
    for (final column in byColumn.keys) {
      if (!first) buf.writeln();
      first = false;
      final count = byColumn[column]!.length;
      buf.writeln('$column ($count)');
      for (final t in byColumn[column]!) {
        buf.writeln('  [${t.id}] (${t.type}) ${t.title}');
      }
    }
    return buf.toString().trimRight();
  }
}
