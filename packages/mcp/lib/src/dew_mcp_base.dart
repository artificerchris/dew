import 'package:dew_core/dew_core.dart';

import 'commands/serve_command.dart';

/// Top-level CLI command for MCP server operations.
class McpCommand extends DewCommand {
  McpCommand(CommandRegistry commandRegistry) {
    addSubcommand(ServeCommand(commandRegistry));
  }

  @override
  final String name = 'mcp';

  @override
  final String description = 'Manage the MCP server.';

  @override
  Future<void> run() async => printUsage();
}
