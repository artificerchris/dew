library;

export 'src/dew_kanban_base.dart';
export 'src/kanban_config.dart';
export 'src/kanban_init_hook.dart';
export 'src/ticket.dart';
export 'src/ticket_store.dart';

import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:dew_kanban/src/dew_kanban_base.dart';
import 'package:dew_kanban/src/kanban_init_hook.dart';

/// Registers all Kanban commands and init hooks into [registry].
void registerCommands(
  CommandRegistry registry, {
  FileSystem fs = const LocalFileSystem(),
}) {
  registry.register(KanbanCommand(fs: fs));
  registry.registerInitHook(KanbanInitHook(fs: fs));
}
