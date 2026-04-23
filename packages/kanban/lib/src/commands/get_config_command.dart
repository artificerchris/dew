import 'package:dew_core/dew_core.dart';

class GetConfigCommand extends DewCommand with DewToolCommand {
  @override
  final String name = 'config';

  @override
  final String description = 'Show the kanban configuration (columns and ticket types).';

  @override
  final String toolName = 'kanban_get_config';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final context = await ProjectContext.find();
    final config = context.config.kanban;

    final columns = config.columns.map((c) => '${c.id} (${c.name})').join(', ');
    final types = config.ticketTypes.map((t) => '${t.id} (${t.name})').join(', ');

    return 'Columns: $columns\nTypes: $types';
  }
}
