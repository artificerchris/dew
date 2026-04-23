import 'package:dart_mcp/server.dart';
import 'package:dew_core/dew_core.dart';

/// An MCP server that serves all tools registered in a [McpToolRegistry].
base class DewMcpServer extends MCPServer with ToolsSupport {
  DewMcpServer(super.channel, List<McpTool> tools)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'dew', version: '1.0.0'),
        instructions:
            'Tools for managing a Dew project (kanban tickets, etc.).',
      ) {
    for (final tool in tools) {
      registerTool(
        Tool(
          name: tool.name,
          description: tool.description,
          // ObjectSchema is an extension type over Map<String,Object?>;
          // pass validateArguments:false to avoid runtime cast issues with
          // nested Map<String,dynamic> literals.
          inputSchema: ObjectSchema.fromMap(
            tool.inputSchema.cast<String, Object?>(),
          ),
        ),
        (request) async {
          final args = (request.arguments ?? const {}).cast<String, dynamic>();
          try {
            final text = await tool.handler(args);
            return CallToolResult(content: [Content.text(text: text)]);
          } catch (e) {
            return CallToolResult(
              content: [Content.text(text: 'Error: $e')],
              isError: true,
            );
          }
        },
        validateArguments: false,
      );
    }
  }
}
