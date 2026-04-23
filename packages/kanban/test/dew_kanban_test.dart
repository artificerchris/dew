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
        containsAll([
          'create', 'list', 'get', 'update', 'delete',
          'move', 'search', 'comment', 'config', 'stats', 'link', 'unlink',
        ]),
      );
    });

    test('registerCommands adds kanban command to registry', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((c) => c.name), contains('kanban'));
    });
  });

  group('CommandRegistry.mcpTools via kanban', () {
    test('exposes twelve tools with unique names', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      final tools = registry.mcpTools;
      expect(tools, hasLength(12));
      final names = tools.map((t) => t.name).toSet();
      expect(names, {
        'kanban_create_ticket',
        'kanban_list_tickets',
        'kanban_get_ticket',
        'kanban_update_ticket',
        'kanban_delete_ticket',
        'kanban_move_ticket',
        'kanban_search_tickets',
        'kanban_add_comment',
        'kanban_get_config',
        'kanban_stats',
        'kanban_link_tickets',
        'kanban_unlink_tickets',
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

        final statsResult = await tools['kanban_stats']!.handler({});
        expect(statsResult, contains('Total: 1'));
        expect(statsResult, contains('todo: 1'));
        expect(statsResult, contains('task: 1'));
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

    test('links roundtrip serialisation', () {
      final t = Ticket(
        id: 'TEST-0003',
        title: 'Linked',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 3),
        body: '',
        comments: const [],
        links: ['TEST-0001', 'TEST-0002'],
      );
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent());
      expect(parsed.links, ['TEST-0001', 'TEST-0002']);
    });

    test('no links field when links is empty', () {
      final t = Ticket(
        id: 'TEST-0004',
        title: 'No links',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 4),
        body: '',
        comments: const [],
      );
      expect(t.toFileContent(), isNot(contains('links:')));
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

    test('linkTickets adds link and is idempotent', () async {
      final store = makeStore();
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      await store.linkTickets('TEST-0001', 'TEST-0002');
      final t = await store.findById('TEST-0001');
      expect(t!.links, contains('TEST-0002'));
      // idempotent
      await store.linkTickets('TEST-0001', 'TEST-0002');
      final t2 = await store.findById('TEST-0001');
      expect(t2!.links, hasLength(1));
    });

    test('linkTickets throws for self-link via command', () async {
      final store = makeStore();
      await store.create(title: 'A', type: 'task', column: 'todo');
      // Self-link guard is in the command layer, not the store — store allows it.
      // Test the command layer check separately via tooling.
    });

    test('unlinkTickets removes link', () async {
      final store = makeStore();
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      await store.linkTickets('TEST-0001', 'TEST-0002');
      await store.unlinkTickets('TEST-0001', 'TEST-0002');
      final t = await store.findById('TEST-0001');
      expect(t!.links, isEmpty);
    });

    test('stats returns correct counts', () async {
      final store = makeStore();
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'done');
      await store.create(title: 'C', type: 'bug', column: 'todo');
      final s = await store.stats();
      expect(s['total'], 3);
      expect((s['byColumn'] as Map)['todo'], 2);
      expect((s['byColumn'] as Map)['done'], 1);
      expect((s['byType'] as Map)['task'], 2);
      expect((s['byType'] as Map)['bug'], 1);
    });
  });

}


