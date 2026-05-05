import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'init.dart';

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

/// Implement this interface to expose tools to the MCP server without needing
/// a CLI command (e.g. a background service or data source).
abstract interface class McpToolProvider {
  List<McpTool> get tools;
}

/// Derives a JSON Schema `object` from an [ArgParser]'s declared options.
///
/// Each option becomes a property:
/// - flags → `boolean`
/// - multi-options → `array` of strings (with `enum` if [Option.allowed] set)
/// - options with [Option.allowed] → `string` with `enum`
/// - all others → `string`
///
/// [Option.help] maps to `description`; [Option.mandatory] adds the name to
/// `required`.
Map<String, dynamic> schemaFromArgParser(ArgParser parser) {
  final properties = <String, dynamic>{};
  final required = <String>[];

  for (final entry in parser.options.entries) {
    final name = entry.key;
    final option = entry.value;
    if (name == 'help') continue;

    final prop = <String, dynamic>{};

    if (option.isFlag) {
      prop['type'] = 'boolean';
    } else if (option.isMultiple) {
      prop['type'] = 'array';
      prop['items'] = option.allowed != null && option.allowed!.isNotEmpty
          ? {'type': 'string', 'enum': option.allowed}
          : {'type': 'string'};
    } else if (option.allowed != null && option.allowed!.isNotEmpty) {
      prop['type'] = 'string';
      prop['enum'] = option.allowed;
    } else {
      prop['type'] = 'string';
    }

    if (option.help != null && option.help!.isNotEmpty) {
      prop['description'] = option.help;
    }

    properties[name] = prop;
    if (option.mandatory) required.add(name);
  }

  return {
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
  };
}

/// Base class for all Dew CLI commands.
///
/// Feature packages extend this class to provide their commands, then register
/// them via [CommandRegistry] so the CLI can assemble them at startup.
abstract class DewCommand extends Command<void> {}

/// Mixin that makes a [DewCommand] also act as an MCP tool.
///
/// Commands only need to provide [toolName] and [callAsTool]. The mixin
/// derives [toolInputSchema] from [ArgParser] automatically, and provides a
/// default [run] implementation that delegates to [callAsTool].
///
/// Override [toolInputSchema] if the derived schema needs adjustment.
mixin DewToolCommand on DewCommand {
  /// The MCP tool name (e.g. `kanban_create_ticket`).
  String get toolName;

  /// JSON Schema for the tool's parameters.
  /// Defaults to a schema derived from [argParser].
  Map<String, dynamic> get toolInputSchema => schemaFromArgParser(argParser);

  /// Executes the command logic given a plain [args] map.
  ///
  /// Returns a human-readable result string.
  /// Both the default [run] and the MCP tool handler delegate here.
  Future<String> callAsTool(Map<String, dynamic> args);

  /// Builds a [McpTool] for this command.
  McpTool toMcpTool() => McpTool(
    name: toolName,
    description: description,
    inputSchema: toolInputSchema,
    handler: callAsTool,
  );

  /// Default implementation: extracts named options from [argResults] and
  /// delegates to [callAsTool], mapping [ArgumentError]s to [usageException].
  @override
  Future<void> run() async {
    final args = <String, dynamic>{};
    for (final name in argParser.options.keys) {
      if (name == 'help') continue;
      args[name] = argResults![name];
    }
    try {
      print(await callAsTool(args));
    } on ArgumentError catch (e) {
      usageException(e.message as String? ?? e.toString());
    }
  }
}

/// Holds the [DewCommand]s registered by feature packages.
///
/// The CLI creates an instance, passes it to each package's
/// `registerCommands` function, then iterates [commands] to populate a
/// [CommandRunner].
class CommandRegistry {
  final List<DewCommand> _commands = [];
  final List<DewInitHook> _initHooks = [];

  /// Adds [command] to the registry.
  void register(DewCommand command) => _commands.add(command);

  /// Registers an [DewInitHook] to be called during `dew init`.
  void registerInitHook(DewInitHook hook) => _initHooks.add(hook);

  /// An unmodifiable view of all registered commands.
  List<DewCommand> get commands => List.unmodifiable(_commands);

  /// An unmodifiable view of all registered init hooks.
  List<DewInitHook> get initHooks => List.unmodifiable(_initHooks);

  /// Collects all [McpTool]s from commands that mix in [DewToolCommand],
  /// recursively including subcommands.
  List<McpTool> get mcpTools {
    final tools = <McpTool>[];
    void collect(Command<void> cmd) {
      if (cmd is DewToolCommand) tools.add(cmd.toMcpTool());
      if (cmd is McpToolProvider) {
        tools.addAll((cmd as McpToolProvider).tools);
      }
      for (final sub in cmd.subcommands.values) {
        collect(sub);
      }
    }

    for (final cmd in _commands) {
      collect(cmd);
    }
    return tools;
  }
}
