import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/dew_kanban.dart' as kanban;
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

    test('collects extra tools from McpToolProvider commands', () {
      final registry = CommandRegistry();
      registry.register(_StubProviderCommand());
      expect(registry.mcpTools, hasLength(1));
      expect(registry.mcpTools.first.name, 'provided_tool');
    });
  });

  group('Kanban MCP tools via CommandRegistry', () {
    late List<McpTool> tools;

    setUp(() {
      final registry = CommandRegistry();
      kanban.registerCommands(registry);
      tools = registry.mcpTools;
    });

    test('all 15 expected tool names are registered', () {
      expect(tools, hasLength(15));
      expect(tools.map((t) => t.name).toSet(), {
        'kanban_create_ticket',
        'kanban_list_tickets',
        'kanban_board',
        'kanban_get_ticket',
        'kanban_update_ticket',
        'kanban_delete_ticket',
        'kanban_archive_ticket',
        'kanban_unarchive_ticket',
        'kanban_move_ticket',
        'kanban_search_tickets',
        'kanban_add_comment',
        'kanban_get_config',
        'kanban_stats',
        'kanban_link_tickets',
        'kanban_unlink_tickets',
      });
    });

    test('kanban_create_ticket schema requires title and type', () {
      final create = tools.firstWhere((t) => t.name == 'kanban_create_ticket');
      final required = create.inputSchema['required'] as List;
      expect(required, containsAll(['title', 'type']));
    });

    test('kanban_add_comment schema requires id and comment', () {
      final comment = tools.firstWhere((t) => t.name == 'kanban_add_comment');
      final required = comment.inputSchema['required'] as List;
      expect(required, containsAll(['id', 'comment']));
    });

    test('kanban_search_tickets schema requires query', () {
      final search = tools.firstWhere((t) => t.name == 'kanban_search_tickets');
      final required = search.inputSchema['required'] as List;
      expect(required, contains('query'));
    });

    test('all tool names follow the snake_case kanban_ prefix pattern', () {
      final pattern = RegExp(r'^kanban_[a-z]+(_[a-z]+)*$');
      for (final tool in tools) {
        expect(
          pattern.hasMatch(tool.name),
          isTrue,
          reason: '${tool.name} does not match snake_case kanban_ pattern',
        );
      }
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

class _StubProviderCommand extends DewCommand implements McpToolProvider {
  @override
  final String name = 'provider';
  @override
  final String description = 'Provider.';

  @override
  List<McpTool> get tools => [
    McpTool(
      name: 'provided_tool',
      description: 'A provided tool.',
      inputSchema: const {'type': 'object'},
      handler: (_) async => 'ok',
    ),
  ];

  @override
  Future<void> run() async => printUsage();
}
