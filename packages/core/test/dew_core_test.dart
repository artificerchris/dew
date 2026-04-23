import 'dart:io';

import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;
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
    late Directory tempDir;
    late Directory originalDir;

    setUp(() async {
      originalDir = Directory.current;
      tempDir = await Directory.systemTemp.createTemp('dew_core_test_');
      await Directory(p.join(tempDir.path, '.project')).create();
      await File(
        p.join(tempDir.path, '.project', 'dew.yaml'),
      ).writeAsString('''
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
''');
      Directory.current = tempDir;
    });

    tearDown(() async {
      Directory.current = originalDir;
      await tempDir.delete(recursive: true);
    });

    test('find() loads config and exposes raw yaml', () async {
      final ctx = await ProjectContext.find();
      final dew = ctx.config.raw['dew'];
      expect(dew['kanban']['prefix'], 'TEST');
      expect(dew['mcp']['host'], 'localhost');
      expect(dew['mcp']['port'], 9090);
    });

    test('find() locates config from a subdirectory', () async {
      final sub = await Directory(p.join(tempDir.path, 'sub')).create();
      Directory.current = sub;
      final ctx = await ProjectContext.find();
      expect(ctx.root, tempDir.path);
    });
  });
}
