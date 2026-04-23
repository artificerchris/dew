import 'package:dew_core/dew_core.dart';

/// Top-level CLI command for all Kanban board operations.
class KanbanCommand extends DewCommand {
  @override
  final String name = 'kanban';

  @override
  final String description = 'Manage the Kanban board.';

  @override
  Future<void> run() async => printUsage();
}
