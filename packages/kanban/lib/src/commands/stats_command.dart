import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import '../ticket_store.dart';

class StatsCommand extends DewCommand with DewToolCommand {
  @override
  final String name = 'stats';

  @override
  final String description = 'Show ticket counts grouped by column and type.';

  @override
  final String toolName = 'kanban_stats';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final context = await ProjectContext.find();
    final config = context.config.kanban;
    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );

    final stats = await store.stats();
    final total = stats['total'] as int;
    final byColumn = stats['byColumn'] as Map<String, int>;
    final byType = stats['byType'] as Map<String, int>;

    final buf = StringBuffer('Total: $total\n\nBy column:');
    for (final col in config.columns) {
      buf.write('\n  ${col.id}: ${byColumn[col.id] ?? 0}');
    }
    buf.write('\n\nBy type:');
    for (final t in config.ticketTypes) {
      buf.write('\n  ${t.id}: ${byType[t.id] ?? 0}');
    }
    return buf.toString();
  }
}
