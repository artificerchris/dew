library;

export 'src/dew_kanban_base.dart';
export 'src/kanban_config.dart';
export 'src/kanban_init_hook.dart';
export 'src/ticket.dart';
export 'src/ticket_store.dart';

import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/src/dew_kanban_base.dart';
import 'package:dew_kanban/src/kanban_init_hook.dart';

/// Registers all Kanban commands and init hooks into [registry].
void registerCommands(CommandRegistry registry) {
  registry.register(KanbanCommand());
  registry.registerInitHook(KanbanInitHook());
}
