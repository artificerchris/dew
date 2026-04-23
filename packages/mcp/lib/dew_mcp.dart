library;

export 'src/dew_mcp_base.dart';
export 'src/mcp_tool_registry.dart';

import 'package:dew_core/dew_core.dart';
import 'package:dew_mcp/src/dew_mcp_base.dart';
import 'package:dew_mcp/src/mcp_tool_registry.dart';

/// Registers the MCP command into [commandRegistry].
///
/// [toolRegistry] is passed to [McpCommand] so the `serve` subcommand can
/// start the server with all registered tool providers.
void registerCommands(
  CommandRegistry commandRegistry,
  McpToolRegistry toolRegistry,
) {
  commandRegistry.register(McpCommand(toolRegistry));
}
