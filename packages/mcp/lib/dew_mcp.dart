library;

export 'src/dew_mcp_base.dart';

import 'package:dew_core/dew_core.dart';
import 'package:dew_mcp/src/dew_mcp_base.dart';

/// Registers all MCP commands into [registry].
void registerCommands(CommandRegistry registry) {
  registry.register(McpCommand());
}

// TODO: Export any libraries intended for clients of this package.
