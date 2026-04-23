typedef McpToolHandler = Future<String> Function(Map<String, dynamic> args);

/// A single tool exposed to an MCP client.
class McpTool {
  final String name;
  final String description;

  /// Raw JSON Schema object (type: object) describing the tool's parameters.
  final Map<String, dynamic> inputSchema;

  final McpToolHandler handler;

  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });
}

/// Implement this interface to expose tools to the MCP server.
///
/// Feature packages implement this in their own library without needing to
/// depend on [packages/mcp] — they only depend on [packages/core].
abstract interface class McpToolProvider {
  List<McpTool> get tools;
}
