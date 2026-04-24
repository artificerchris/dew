import 'package:dew_core/dew_core.dart';

import 'commands/add_comment_command.dart';
import 'commands/archive_command.dart';
import 'commands/board_command.dart';
import 'commands/create_command.dart';
import 'commands/delete_command.dart';
import 'commands/get_command.dart';
import 'commands/get_config_command.dart';
import 'commands/link_command.dart';
import 'commands/list_command.dart';
import 'commands/move_command.dart';
import 'commands/search_command.dart';
import 'commands/stats_command.dart';
import 'commands/unarchive_command.dart';
import 'commands/unlink_command.dart';
import 'commands/update_command.dart';

/// Top-level CLI command for all Kanban board operations.
class KanbanCommand extends DewCommand {
  KanbanCommand() {
    addSubcommand(CreateCommand());
    addSubcommand(ListCommand());
    addSubcommand(BoardCommand());
    addSubcommand(GetCommand());
    addSubcommand(UpdateCommand());
    addSubcommand(DeleteCommand());
    addSubcommand(ArchiveCommand());
    addSubcommand(UnarchiveCommand());
    addSubcommand(MoveCommand());
    addSubcommand(SearchCommand());
    addSubcommand(AddCommentCommand());
    addSubcommand(GetConfigCommand());
    addSubcommand(StatsCommand());
    addSubcommand(LinkCommand());
    addSubcommand(UnlinkCommand());
  }

  @override
  final String name = 'kanban';

  @override
  final String description = 'Manage the Kanban board.';

  @override
  Future<void> run() async => printUsage();
}
