import 'package:dew_core/dew_core.dart';

import 'commands/delete_command.dart';
import 'commands/generate_command.dart';
import 'commands/get_command.dart';
import 'commands/init_command.dart';
import 'commands/list_command.dart';
import 'commands/rename_command.dart';
import 'commands/rotate_command.dart';
import 'commands/set_command.dart';
import 'commands/update_command.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

/// Top-level CLI command for all Vault operations.
class VaultCommand extends DewCommand {
  VaultCommand({FileSystem fs = const LocalFileSystem()}) {
    addSubcommand(VaultInitCommand(fs: fs));
    addSubcommand(ListCommand(fs: fs));
    addSubcommand(SetCommand(fs: fs));
    addSubcommand(GetCommand(fs: fs));
    addSubcommand(UpdateCommand(fs: fs));
    addSubcommand(RenameCommand(fs: fs));
    addSubcommand(RotateCommand(fs: fs));
    addSubcommand(GenerateCommand(fs: fs));
    addSubcommand(DeleteCommand(fs: fs));
  }

  @override
  final String name = 'vault';

  @override
  final String description = 'Manage project secrets with a local vault.';

  @override
  Future<void> run() async => printUsage();
}
