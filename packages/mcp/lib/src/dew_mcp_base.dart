import 'package:dew_core/dew_core.dart';

/// Top-level CLI command for MCP server operations.
class McpCommand extends DewCommand {
  @override
  final String name = 'mcp';

  @override
  final String description = 'Manage the MCP server.';

  @override
  Future<void> run() async => printUsage();
}
