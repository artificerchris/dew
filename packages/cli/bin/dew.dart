import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:dew_infra/dew_infra.dart' as infra;
import 'package:dew_kanban/dew_kanban.dart' as kanban;
import 'package:dew_mcp/dew_mcp.dart' as mcp;
import 'package:dew_vault/dew_vault.dart' as vault;

Future<void> main(List<String> args) async {
  final commandRegistry = CommandRegistry();

  infra.registerCommands(commandRegistry);
  kanban.registerCommands(commandRegistry);
  vault.registerCommands(commandRegistry);
  mcp.registerCommands(commandRegistry);

  final runner = CommandRunner<void>('dew', 'A project management tool.');

  runner.addCommand(InitCommand(commandRegistry.initHooks));
  for (final command in commandRegistry.commands) {
    runner.addCommand(command);
  }

  try {
    await runner.run(args);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
}
