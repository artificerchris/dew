library;

export 'src/dew_mcp_base.dart';

import 'package:dew_core/dew_core.dart';
import 'package:dew_mcp/src/dew_mcp_base.dart';

/// Registers the MCP command into [commandRegistry].
///
/// Tools are resolved lazily from [commandRegistry.mcpTools] when the server
/// starts, so all feature packages must call their own [registerCommands]
/// before this is invoked.
void registerCommands(CommandRegistry commandRegistry) {
  commandRegistry.register(McpCommand(commandRegistry));
}
