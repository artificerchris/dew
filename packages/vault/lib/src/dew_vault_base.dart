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

/// Top-level CLI command for all Vault operations.
class VaultCommand extends DewCommand {
  VaultCommand() {
    addSubcommand(VaultInitCommand());
    addSubcommand(ListCommand());
    addSubcommand(SetCommand());
    addSubcommand(GetCommand());
    addSubcommand(UpdateCommand());
    addSubcommand(RenameCommand());
    addSubcommand(RotateCommand());
    addSubcommand(GenerateCommand());
    addSubcommand(DeleteCommand());
  }

  @override
  final String name = 'vault';

  @override
  final String description = 'Manage project secrets with a local vault.';

  @override
  Future<void> run() async => printUsage();
}
