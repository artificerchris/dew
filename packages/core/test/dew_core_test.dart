import 'package:dew_core/dew_core.dart';
import 'package:test/test.dart';

// Minimal concrete command for testing the registry.
class _TestCommand extends DewCommand {
  @override
  final String name = 'test-cmd';
  @override
  final String description = 'A test command.';
  @override
  Future<void> run() async {}
}

void main() {
  group('CommandRegistry', () {
    test('starts empty', () {
      final registry = CommandRegistry();
      expect(registry.commands, isEmpty);
    });

    test('register adds a command', () {
      final registry = CommandRegistry();
      registry.register(_TestCommand());
      expect(registry.commands, hasLength(1));
      expect(registry.commands.first.name, 'test-cmd');
    });

    test('commands list is unmodifiable', () {
      final registry = CommandRegistry();
      expect(() => registry.commands.add(_TestCommand()), throwsUnsupportedError);
    });
  });
}
