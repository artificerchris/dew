import 'dart:io';

import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/dew_kanban.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('KanbanCommand', () {
    test('has correct name and description', () {
      final cmd = KanbanCommand();
      expect(cmd.name, 'kanban');
      expect(cmd.description, isNotEmpty);
    });

    test('has expected subcommands', () {
      final cmd = KanbanCommand();
      expect(
        cmd.subcommands.keys,
        containsAll(['create', 'list', 'get', 'update', 'delete', 'search', 'comment', 'config']),
      );
    });

    test('registerCommands adds kanban command to registry', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((c) => c.name), contains('kanban'));
    });
  });

  group('CommandRegistry.mcpTools via kanban', () {
    test('exposes eight tools with unique names', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      final tools = registry.mcpTools;
      expect(tools, hasLength(8));
      final names = tools.map((t) => t.name).toSet();
      expect(names, {
        'kanban_create_ticket',
        'kanban_list_tickets',
        'kanban_get_ticket',
        'kanban_update_ticket',
        'kanban_delete_ticket',
        'kanban_search_tickets',
        'kanban_add_comment',
        'kanban_get_config',
      });
    });

    test('all tools have non-empty descriptions and object inputSchema', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      for (final tool in registry.mcpTools) {
        expect(tool.description, isNotEmpty, reason: '${tool.name} description');
        expect(tool.inputSchema['type'], 'object', reason: '${tool.name} schema type');
      }
    });

    test('schema derived from argParser — create tool has required fields', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      final create = registry.mcpTools.firstWhere((t) => t.name == 'kanban_create_ticket');
      final required = create.inputSchema['required'] as List;
      expect(required, containsAll(['title', 'type']));
    });

    test('create and list tools have working handlers', () async {
      final tempDir = await Directory.systemTemp.createTemp('kanban_tool_test_');
      final origDir = Directory.current;
      try {
        await Directory(p.join(tempDir.path, '.project', 'kanban')).create(recursive: true);
        await File(p.join(tempDir.path, '.project', 'dew.yaml')).writeAsString('''
dew:
  mcp:
    host: localhost
    port: 9090
  kanban:
    prefix: T
    ticket_types:
      - id: task
        name: Task
    columns:
      - id: todo
        name: To Do
        color: blue
''');
        Directory.current = tempDir;
        final registry = CommandRegistry();
        registerCommands(registry);
        final tools = {for (final t in registry.mcpTools) t.name: t};

        final result = await tools['kanban_create_ticket']!.handler({
          'title': 'Hello',
          'type': 'task',
        });
        expect(result, contains('T-0001'));

        final listResult = await tools['kanban_list_tickets']!.handler({});
        expect(listResult, contains('T-0001'));

        final searchResult = await tools['kanban_search_tickets']!.handler({'query': 'Hello'});
        expect(searchResult, contains('T-0001'));

        await tools['kanban_add_comment']!.handler({'id': 'T-0001', 'comment': 'Nice ticket.'});

        final getResult = await tools['kanban_get_ticket']!.handler({'id': 'T-0001'});
        expect(getResult, contains('Nice ticket.'));

        final configResult = await tools['kanban_get_config']!.handler({});
        expect(configResult, contains('todo'));
        expect(configResult, contains('task'));
      } finally {
        Directory.current = origDir;
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('Ticket', () {
    test('roundtrip serialisation', () {
      final t = Ticket(
        id: 'TEST-0001',
        title: 'Do a thing',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 1, 12),
        body: 'Some body.',
        comments: ['First comment.', 'Second comment.'],
      );
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent());
      expect(parsed.id, t.id);
      expect(parsed.title, t.title);
      expect(parsed.type, t.type);
      expect(parsed.column, t.column);
      expect(parsed.created.toUtc(), t.created.toUtc());
      expect(parsed.body, t.body);
      expect(parsed.comments, t.comments);
    });

    test('empty body and no comments', () {
      final t = Ticket(
        id: 'TEST-0002',
        title: 'Empty',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 2),
        body: '',
        comments: const [],
      );
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent());
      expect(parsed.body, '');
      expect(parsed.comments, isEmpty);
    });
  });

  group('TicketStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dew_kanban_test_');
    });

    tearDown(() => tempDir.delete(recursive: true));

    TicketStore makeStore() => TicketStore(
      kanbanDir: p.join(tempDir.path, 'kanban'),
      prefix: 'TEST',
    );

    test('create assigns incrementing IDs', () async {
      final store = makeStore();
      final t1 = await store.create(
        title: 'First',
        type: 'task',
        column: 'todo',
      );
      final t2 = await store.create(
        title: 'Second',
        type: 'bug',
        column: 'todo',
      );
      expect(t1.id, 'TEST-0001');
      expect(t2.id, 'TEST-0002');
    });

    test('findById returns null for missing ticket', () async {
      final store = makeStore();
      expect(await store.findById('TEST-0099'), isNull);
    });

    test('list returns sorted tickets', () async {
      final store = makeStore();
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      final all = await store.list();
      expect(all.map((t) => t.id), ['TEST-0001', 'TEST-0002']);
    });

    test('update patches specified fields', () async {
      final store = makeStore();
      await store.create(title: 'Old', type: 'task', column: 'todo');
      final updated = await store.update('TEST-0001', title: 'New');
      expect(updated.title, 'New');
      expect(updated.type, 'task');
    });

    test('update throws for missing ticket', () async {
      final store = makeStore();
      expect(
        () => store.update('TEST-0099', title: 'X'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('delete removes ticket', () async {
      final store = makeStore();
      await store.create(title: 'Bye', type: 'task', column: 'todo');
      await store.delete('TEST-0001');
      expect(await store.findById('TEST-0001'), isNull);
    });

    test('delete throws for missing ticket', () async {
      final store = makeStore();
      expect(
        () => store.delete('TEST-0099'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

}


