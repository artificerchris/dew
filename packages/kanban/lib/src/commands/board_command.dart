import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket.dart';
import '../ticket_store.dart';

class BoardCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  BoardCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('type', abbr: 't', help: 'Filter tickets to this type.')
      ..addOption('label', help: 'Filter tickets to this label.')
      ..addOption('milestone', help: 'Filter tickets to this milestone.');
  }

  @override
  final String name = 'board';

  @override
  final String description = 'Show ticket counts grouped by column and type.';

  @override
  final String toolName = 'kanban_board';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final typeFilter = args['type'] as String?;
    final labelFilter = args['label'] as String?;
    final milestoneFilter = args['milestone'] as String?;

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: config.prefix,
      fs: context.fs,
    );

    var tickets = await store.list();
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

    // Index by column, preserving config order.
    final byColumn = <String, List<Ticket>>{};
    for (final col in config.columns) {
      byColumn[col.id] = [];
    }
    for (final t in tickets) {
      (byColumn[t.column] ??= []).add(t);
    }

    if (byColumn.values.every((l) => l.isEmpty)) {
      return 'No tickets found.';
    }

    // Each box is at least wide enough for "  <longest ticket line>  ".
    final Map<String, List<String>> lines = {};
    for (final entry in byColumn.entries) {
      if (entry.value.isEmpty) {
        lines[entry.key] = ['  (empty)'];
      } else {
        lines[entry.key] = entry.value
            .map((t) => '  [${t.id}] (${t.type}) ${t.title}')
            .toList();
      }
    }

    final buf = StringBuffer();
    for (final entry in byColumn.entries) {
      final col = entry.key;
      final header = '  $col (${entry.value.length})  ';
      final colLines = lines[col]!;
      final contentWidth = [
        header.length,
        ...colLines.map((l) => l.length + 2),
      ].reduce((a, b) => a > b ? a : b);
      final divider = '─' * contentWidth;
      buf.writeln('┌$divider┐');
      buf.writeln('│${header.padRight(contentWidth)}│');
      buf.writeln('├$divider┤');
      for (final line in colLines) {
        buf.writeln('│${line.padRight(contentWidth)}│');
      }
      buf.writeln('└$divider┘');
    }
    return buf.toString().trimRight();
  }
}
