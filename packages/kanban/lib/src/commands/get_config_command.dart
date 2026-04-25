import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

class GetConfigCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  GetConfigCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs;
  @override
  final String name = 'config';

  @override
  final String description =
      'Show the kanban configuration (columns and ticket types).';

  @override
  final String toolName = 'kanban_get_config';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;

    final columns = config.columns.map((c) => '${c.id} (${c.name})').join(', ');
    final types = config.ticketTypes
        .map((t) => '${t.id} (${t.name})')
        .join(', ');

    return 'Columns: $columns\nTypes: $types';
  }
}
