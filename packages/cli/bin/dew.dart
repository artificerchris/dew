import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/dew_kanban.dart' as kanban;
import 'package:dew_mcp/dew_mcp.dart' as mcp;

Future<void> main(List<String> args) async {
  final commandRegistry = CommandRegistry();

  kanban.registerCommands(commandRegistry);
  mcp.registerCommands(commandRegistry);

  final runner = CommandRunner<void>('dew', 'A project management tool.');

  runner.addCommand(InitCommand(commandRegistry.initHooks));
  for (final command in commandRegistry.commands) {
    runner.addCommand(command);
  }

  await runner.run(args);
}
