import 'package:dew_core/dew_core.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

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
      expect(
        () => registry.commands.add(_TestCommand()),
        throwsUnsupportedError,
      );
    });
  });

  group('ProjectContext', () {
    const configYaml = '''
dew:
  mcp:
    host: localhost
    port: 9090
  kanban:
    prefix: TEST
    ticket_types:
      - id: task
        name: Task
    columns:
      - id: todo
        name: To Do
        color: blue
''';

    test('find() loads config and exposes raw yaml', () async {
      final fs = MemoryFileSystem();
      fs.directory('/.project').createSync(recursive: true);
      fs.file('/.project/dew.yaml').writeAsStringSync(configYaml);

      final ctx = await ProjectContext.find(fs: fs);
      final dew = ctx.config.raw['dew'];
      expect(dew['kanban']['prefix'], 'TEST');
      expect(dew['mcp']['host'], 'localhost');
      expect(dew['mcp']['port'], 9090);
    });

    test('find() locates config from a subdirectory', () async {
      final fs = MemoryFileSystem();
      fs.directory('/.project').createSync(recursive: true);
      fs.file('/.project/dew.yaml').writeAsStringSync(configYaml);
      fs.directory('/sub').createSync(recursive: true);

      final ctx = await ProjectContext.find(fs: fs, from: fs.directory('/sub'));
      expect(ctx.root, '/');
    });
  });
}
