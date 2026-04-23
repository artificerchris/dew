import 'package:dew_core/dew_core.dart';
import 'package:dew_mcp/dew_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpCommand', () {
    test('has correct name and description', () {
      final cmd = McpCommand(CommandRegistry());
      expect(cmd.name, 'mcp');
      expect(cmd.description, isNotEmpty);
    });

    test('has serve subcommand', () {
      final cmd = McpCommand(CommandRegistry());
      expect(cmd.subcommands.keys, contains('serve'));
    });

    test('registerCommands adds mcp command to registry', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((c) => c.name), contains('mcp'));
    });
  });

  group('CommandRegistry.mcpTools', () {
    test('starts empty with no feature packages registered', () {
      expect(CommandRegistry().mcpTools, isEmpty);
    });

    test('collects tools from DewToolCommand subcommands', () {
      final registry = CommandRegistry();
      registry.register(_StubParentCommand());
      expect(registry.mcpTools, hasLength(1));
      expect(registry.mcpTools.first.name, 'stub_tool');
    });
  });
}

class _StubToolCommand extends DewCommand with DewToolCommand {
  _StubToolCommand() {
    argParser.addOption('input', mandatory: true, help: 'Some input.');
  }

  @override
  final String name = 'stub';
  @override
  final String description = 'A stub tool command.';
  @override
  final String toolName = 'stub_tool';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async => 'ok';
}

class _StubParentCommand extends DewCommand {
  _StubParentCommand() {
    addSubcommand(_StubToolCommand());
  }

  @override
  final String name = 'parent';
  @override
  final String description = 'Parent.';
  @override
  Future<void> run() async => printUsage();
}

