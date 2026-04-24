import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

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
  KanbanCommand({FileSystem fs = const LocalFileSystem()}) {
    addSubcommand(CreateCommand(fs: fs));
    addSubcommand(ListCommand(fs: fs));
    addSubcommand(BoardCommand(fs: fs));
    addSubcommand(GetCommand(fs: fs));
    addSubcommand(UpdateCommand(fs: fs));
    addSubcommand(DeleteCommand(fs: fs));
    addSubcommand(ArchiveCommand(fs: fs));
    addSubcommand(UnarchiveCommand(fs: fs));
    addSubcommand(MoveCommand(fs: fs));
    addSubcommand(SearchCommand(fs: fs));
    addSubcommand(AddCommentCommand(fs: fs));
    addSubcommand(GetConfigCommand(fs: fs));
    addSubcommand(StatsCommand(fs: fs));
    addSubcommand(LinkCommand(fs: fs));
    addSubcommand(UnlinkCommand(fs: fs));
  }

  @override
  final String name = 'kanban';

  @override
  final String description = 'Manage the Kanban board.';

  @override
  Future<void> run() async => printUsage();
}
