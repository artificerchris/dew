import 'package:dew_mcp/dew_mcp.dart';
import 'package:dew_core/dew_core.dart';
import 'package:test/test.dart';

void main() {
  group('McpCommand', () {
    test('has correct name and description', () {
      final cmd = McpCommand();
      expect(cmd.name, 'mcp');
      expect(cmd.description, isNotEmpty);
    });

    test('registerCommands adds mcp command to registry', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((c) => c.name), contains('mcp'));
    });
  });
}
