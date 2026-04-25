import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:dew_core/dew_core.dart';

import '../dew_mcp_server.dart';

class ServeCommand extends DewCommand {
  final CommandRegistry _commandRegistry;

  ServeCommand(this._commandRegistry);

  @override
  final String name = 'serve';

  @override
  final String description =
      'Start the Dew MCP server on stdio. '
      'Connect your MCP client to this process.';

  @override
  Future<void> run() async {
    // Resolve tools at serve time so all feature packages are already registered.
    final tools = _commandRegistry.mcpTools;

    io.stderr.writeln(
      'Dew MCP server starting — ${tools.length} tool(s) registered.',
    );

    // stdioChannel subscribes to stdin; do not touch stdin after this point.
    // The Dart event loop keeps the process alive until the client disconnects.
    DewMcpServer(stdioChannel(input: io.stdin, output: io.stdout), tools);
  }
}
