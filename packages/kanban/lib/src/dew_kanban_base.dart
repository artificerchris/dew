import 'package:dew_core/dew_core.dart';

import 'commands/add_comment_command.dart';
import 'commands/create_command.dart';
import 'commands/delete_command.dart';
import 'commands/get_command.dart';
import 'commands/get_config_command.dart';
import 'commands/list_command.dart';
import 'commands/search_command.dart';
import 'commands/update_command.dart';

/// Top-level CLI command for all Kanban board operations.
class KanbanCommand extends DewCommand {
  KanbanCommand() {
    addSubcommand(CreateCommand());
    addSubcommand(ListCommand());
    addSubcommand(GetCommand());
    addSubcommand(UpdateCommand());
    addSubcommand(DeleteCommand());
    addSubcommand(SearchCommand());
    addSubcommand(AddCommentCommand());
    addSubcommand(GetConfigCommand());
  }

  @override
  final String name = 'kanban';

  @override
  final String description = 'Manage the Kanban board.';

  @override
  Future<void> run() async => printUsage();
}
