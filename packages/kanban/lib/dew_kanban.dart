library;

export 'src/dew_kanban_base.dart';
export 'src/kanban_tool_provider.dart';
export 'src/ticket.dart';
export 'src/ticket_store.dart';

import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/src/dew_kanban_base.dart';

/// Registers all Kanban commands into [registry].
void registerCommands(CommandRegistry registry) {
  registry.register(KanbanCommand());
}
