import 'package:dew_core/dew_core.dart';
import 'package:dew_mcp/dew_mcp.dart';
import 'package:test/test.dart';

class _PingProvider implements McpToolProvider {
  @override
  List<McpTool> get tools => [
    McpTool(
      name: 'ping',
      description: 'Returns pong.',
      inputSchema: {'type': 'object', 'properties': {}},
      handler: (_) async => 'pong',
    ),
  ];
}

void main() {
  group('McpCommand', () {
    test('has correct name and description', () {
      final cmd = McpCommand(McpToolRegistry());
      expect(cmd.name, 'mcp');
      expect(cmd.description, isNotEmpty);
    });

    test('has serve subcommand', () {
      final cmd = McpCommand(McpToolRegistry());
      expect(cmd.subcommands.keys, contains('serve'));
    });

    test('registerCommands adds mcp command to registry', () {
      final commandRegistry = CommandRegistry();
      registerCommands(commandRegistry, McpToolRegistry());
      expect(commandRegistry.commands.map((c) => c.name), contains('mcp'));
    });
  });

  group('McpToolRegistry', () {
    test('starts empty', () {
      expect(McpToolRegistry().allTools, isEmpty);
    });

    test('register adds provider tools', () {
      final registry = McpToolRegistry();
      registry.register(_PingProvider());
      expect(registry.allTools, hasLength(1));
      expect(registry.allTools.first.name, 'ping');
    });

    test('aggregates tools from multiple providers', () {
      final registry = McpToolRegistry();
      registry.register(_PingProvider());
      registry.register(_PingProvider());
      expect(registry.allTools, hasLength(2));
    });
  });
}

