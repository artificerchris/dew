import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/dew_kanban.dart' as kanban;
import 'package:dew_mcp/dew_mcp.dart' as mcp;

Future<void> main(List<String> args) async {
  final registry = CommandRegistry();
  kanban.registerCommands(registry);
  mcp.registerCommands(registry);

  final runner = CommandRunner<void>(
    'dew',
    'A project management tool.',
  );

  for (final command in registry.commands) {
    runner.addCommand(command);
  }

  await runner.run(args);
}
