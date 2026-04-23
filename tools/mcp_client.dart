/// Manual MCP client for debugging the Dew MCP server.
///
/// Usage:
///   dart run tools/mcp_client.dart [path/to/dew/binary]
///
/// Defaults to .project/toolchain/bin/dew if no path is given.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';

void main(List<String> args) async {
  final binaryPath = args.isNotEmpty
      ? args.first
      : '.project/toolchain/bin/dew';

  print('=== Dew MCP Debug Client ===');
  print('Binary: $binaryPath');
  print('');

  // Log all raw JSON-RPC traffic.
  final protocolLog = StreamController<String>();
  protocolLog.stream.listen((msg) => stderr.writeln('[proto] $msg'));

  // Start the server process.
  print('Starting server process...');
  final process = await Process.start(
    binaryPath,
    ['mcp', 'serve'],
    // Forward server stderr to our stderr so startup messages are visible.
  );

  // Print server stderr in real time.
  process.stderr
      .transform(SystemEncoding().decoder)
      .listen((line) => stderr.write('[server] $line'));

  unawaited(
    process.exitCode.then((code) {
      if (code != 0) {
        stderr.writeln('[client] Server process exited with code $code');
      }
    }),
  );

  final client = MCPClient(
    Implementation(name: 'dew-debug-client', version: '0.1.0'),
  );

  final connection = client.connectServer(
    stdioChannel(input: process.stdout, output: process.stdin),
    protocolLogSink: protocolLog.sink,
  );

  unawaited(connection.done.then((_) {
    stderr.writeln('[client] Connection closed.');
    process.kill();
  }));

  // --- Initialise ---
  print('Sending initialize...');
  late InitializeResult initResult;
  try {
    initResult = await connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    ).timeout(const Duration(seconds: 5));
  } on TimeoutException {
    stderr.writeln('[client] Timed out waiting for initialize response.');
    process.kill();
    exit(1);
  } catch (e) {
    stderr.writeln('[client] Initialize failed: $e');
    process.kill();
    exit(1);
  }

  print('Server: ${initResult.serverInfo?.name} ${initResult.serverInfo?.version}');
  print('Protocol: ${initResult.protocolVersion}');
  print('');

  if (initResult.capabilities.tools == null) {
    stderr.writeln('[client] Server does not advertise tools capability.');
    await client.shutdown();
    process.kill();
    exit(1);
  }

  connection.notifyInitialized();

  // --- List tools ---
  print('Listing tools...');
  final toolsResult = await connection.listTools(ListToolsRequest());
  if (toolsResult.tools.isEmpty) {
    print('  (no tools registered)');
  } else {
    for (final tool in toolsResult.tools) {
      print('  • ${tool.name}: ${tool.description ?? "(no description)"}');
    }
  }

  print('');

  // --- Call kanban_list_tickets ---
  print('Calling kanban_list_tickets...');
  try {
    final result = await connection.callTool(
      CallToolRequest(name: 'kanban_list_tickets', arguments: {}),
    );
    if (result.isError == true) {
      print('  Error: ${result.content.map((c) => (c as TextContent).text).join()}');
    } else {
      print('  Result:');
      for (final c in result.content) {
        print('    ${(c as TextContent).text}');
      }
    }
  } catch (e) {
    print('  Failed: $e');
  }

  print('');
  print('Done. Shutting down.');
  await client.shutdown();
  process.kill();
}
