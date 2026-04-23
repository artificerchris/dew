import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:dew_core/dew_core.dart';

import '../dew_mcp_server.dart';
import '../mcp_tool_registry.dart';

class ServeCommand extends DewCommand {
  final McpToolRegistry _toolRegistry;

  ServeCommand(this._toolRegistry);

  @override
  final String name = 'serve';

  @override
  final String description =
      'Start the Dew MCP server on stdio. '
      'Connect your MCP client to this process.';

  @override
  Future<void> run() async {
    final context = await ProjectContext.find();
    final tools = _toolRegistry.allTools;

    io.stderr.writeln(
      'Dew MCP server starting — '
      '${tools.length} tool(s) registered, '
      'project root: ${context.root}',
    );

    DewMcpServer(
      stdioChannel(input: io.stdin, output: io.stdout),
      tools,
    );

    // Keep the process alive until the MCP client closes the connection.
    await io.stdin.drain<void>();
  }
}
