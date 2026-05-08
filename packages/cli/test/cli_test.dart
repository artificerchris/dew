import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:dew_infra/dew_infra.dart' as infra;
import 'package:dew_kanban/dew_kanban.dart' as kanban;
import 'package:dew_mcp/dew_mcp.dart' as mcp;
import 'package:dew_vault/dew_vault.dart' as vault;
import 'package:test/test.dart';

/// Builds the same CommandRunner as bin/dew.dart without actually running it.
CommandRunner<void> buildRunner() {
  final commandRegistry = CommandRegistry();
  infra.registerCommands(commandRegistry);
  kanban.registerCommands(commandRegistry);
  vault.registerCommands(commandRegistry);
  mcp.registerCommands(commandRegistry);

  final runner = CommandRunner<void>('dew', 'A project management tool.');
  runner.addCommand(CompletionCommand());
  runner.addCommand(InitCommand(commandRegistry.initHooks));
  for (final command in commandRegistry.commands) {
    runner.addCommand(command);
  }
  return runner;
}

void main() {
  group('CLI CommandRunner', () {
    test('builds without throwing', () {
      expect(buildRunner, returnsNormally);
    });

    test('has core package commands registered', () {
      final runner = buildRunner();
      expect(
        runner.commands.keys,
        containsAll(['infra', 'kanban', 'vault', 'init', 'mcp', 'completion']),
      );
    });

    test('--help flag does not throw', () async {
      final runner = buildRunner();
      await expectLater(runner.run(['--help']), completes);
    });

    test('unknown command throws UsageException', () async {
      final runner = buildRunner();
      await expectLater(
        runner.run(['totally-unknown-command']),
        throwsA(isA<UsageException>()),
      );
    });

    test('kanban subcommand --help does not throw', () async {
      final runner = buildRunner();
      await expectLater(runner.run(['help', 'kanban']), completes);
    });

    test('mcp subcommand --help does not throw', () async {
      final runner = buildRunner();
      await expectLater(runner.run(['help', 'mcp']), completes);
    });

    test('completion subcommand --help does not throw', () async {
      final runner = buildRunner();
      await expectLater(runner.run(['help', 'completion']), completes);
    });

    test('completion scaffolds subcommand --help does not throw', () async {
      final runner = buildRunner();
      await expectLater(runner.run(['help', 'completion', 'scaffolds']), completes);
    });
  });
}
