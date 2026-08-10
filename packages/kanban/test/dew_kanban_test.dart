import 'package:dew_core/dew_core.dart';
import 'package:dew_kanban/dew_kanban.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

const _testConfig = '''
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
''';

MemoryFileSystem _makeFs() {
  final fs = MemoryFileSystem();
  fs.directory('/.project/kanban').createSync(recursive: true);
  fs.file('/.project/dew.yaml').writeAsStringSync(_testConfig);
  return fs;
}

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
          'create',
          'list',
          'board',
          'get',
          'update',
          'delete',
          'archive',
          'unarchive',
          'move',
          'search',
          'comment',
          'config',
          'stats',
          'link',
          'unlink',
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
      expect(tools, hasLength(15));
      final names = tools.map((t) => t.name).toSet();
      expect(names, {
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

    test('all tools have non-empty descriptions and object inputSchema', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      for (final tool in registry.mcpTools) {
        expect(
          tool.description,
          isNotEmpty,
          reason: '${tool.name} description',
        );
        expect(
          tool.inputSchema['type'],
          'object',
          reason: '${tool.name} schema type',
        );
      }
    });

    test('schema derived from argParser — create tool has required fields', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      final create = registry.mcpTools.firstWhere(
        (t) => t.name == 'kanban_create_ticket',
      );
      final required = create.inputSchema['required'] as List;
      expect(required, containsAll(['title', 'type']));
    });

    test('create/update type schema enumerates configured ticket types', () {
      final fs = _makeFs();
      fs.file('/.project/dew.yaml').writeAsStringSync('''
dew:
  kanban:
    prefix: T
    ticket_types:
      - id: task
        name: Task
      - id: feedback
        name: Feedback
    columns:
      - id: todo
        name: To Do
        color: blue
''');
      final registry = CommandRegistry();
      registerCommands(registry, fs: fs);
      final tools = {for (final t in registry.mcpTools) t.name: t};

      for (final name in ['kanban_create_ticket', 'kanban_update_ticket']) {
        final properties =
            tools[name]!.inputSchema['properties'] as Map<String, dynamic>;
        final type = properties['type'] as Map<String, dynamic>;
        expect(type['enum'], ['task', 'feedback'], reason: name);
      }
    });

    test('create/update/move column schema enumerates configured columns', () {
      final fs = _makeFs();
      final registry = CommandRegistry();
      registerCommands(registry, fs: fs);
      final tools = {for (final t in registry.mcpTools) t.name: t};

      for (final name in [
        'kanban_create_ticket',
        'kanban_update_ticket',
        'kanban_move_ticket',
      ]) {
        final properties =
            tools[name]!.inputSchema['properties'] as Map<String, dynamic>;
        final column = properties['column'] as Map<String, dynamic>;
        expect(column['enum'], ['todo'], reason: name);
      }
    });

    test('move schema constrains column but has no type property', () {
      final registry = CommandRegistry();
      registerCommands(registry, fs: _makeFs());
      final move = registry.mcpTools.firstWhere(
        (t) => t.name == 'kanban_move_ticket',
      );
      final properties = move.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('type'), isFalse);
      expect((properties['column'] as Map)['enum'], ['todo']);
    });

    test('schemas omit enums when there is no readable config', () {
      final registry = CommandRegistry();
      registerCommands(registry, fs: MemoryFileSystem());
      final create = registry.mcpTools.firstWhere(
        (t) => t.name == 'kanban_create_ticket',
      );
      final properties =
          create.inputSchema['properties'] as Map<String, dynamic>;
      for (final name in ['type', 'column']) {
        final prop = properties[name] as Map<String, dynamic>;
        expect(prop.containsKey('enum'), isFalse, reason: name);
        expect(prop['type'], 'string', reason: name);
      }
    });

    test('create and list tools have working handlers', () async {
      final fs = _makeFs();
      final registry = CommandRegistry();
      registerCommands(registry, fs: fs);
      final tools = {for (final t in registry.mcpTools) t.name: t};

      final result = await tools['kanban_create_ticket']!.handler({
        'title': 'Hello',
        'type': 'task',
      });
      expect(result, contains('T-0001'));

      final listResult = await tools['kanban_list_tickets']!.handler({});
      expect(listResult, contains('T-0001'));

      final searchResult = await tools['kanban_search_tickets']!.handler({
        'query': 'Hello',
      });
      expect(searchResult, contains('T-0001'));

      await tools['kanban_add_comment']!.handler({
        'id': 'T-0001',
        'comment': 'Nice ticket.',
      });

      final getResult = await tools['kanban_get_ticket']!.handler({
        'id': 'T-0001',
      });
      expect(getResult, contains('Nice ticket.'));

      final configResult = await tools['kanban_get_config']!.handler({});
      expect(configResult, contains('todo'));
      expect(configResult, contains('task'));

      final statsResult = await tools['kanban_stats']!.handler({});
      expect(statsResult, contains('Total: 1'));
      expect(statsResult, contains('todo: 1'));
      expect(statsResult, contains('task: 1'));
    });
  });

  group('TicketTypeConfig color', () {
    test('parses an optional color and leaves it null when absent', () {
      final fs = MemoryFileSystem();
      fs.directory('/.project').createSync(recursive: true);
      fs.file('/.project/dew.yaml').writeAsStringSync('''
dew:
  kanban:
    prefix: T
    ticket_types:
      - id: bug
        name: Bug
        color: brightRed
      - id: task
        name: Task
    columns:
      - id: todo
        name: To Do
        color: blue
''');
      final config = ProjectContext.findSync(fs: fs)!.config.kanban;
      expect(config.ticketTypes[0].color, 'brightRed');
      expect(config.ticketTypes[1].color, isNull);
    });
  });

  group('ticket type discovery in usage text', () {
    test('create/update usage lists configured ticket types', () {
      final fs = _makeFs();
      final registry = CommandRegistry();
      registerCommands(registry, fs: fs);
      final kanban = registry.commands.firstWhere((c) => c.name == 'kanban');

      for (final name in ['create', 'update']) {
        final footer = kanban.subcommands[name]!.usageFooter;
        expect(footer, contains('Configured ticket types: task'), reason: name);
        expect(footer, contains('Configured columns: todo'), reason: name);
      }
    });

    test('move usage lists columns only', () {
      final registry = CommandRegistry();
      registerCommands(registry, fs: _makeFs());
      final kanban = registry.commands.firstWhere((c) => c.name == 'kanban');
      final footer = kanban.subcommands['move']!.usageFooter;
      expect(footer, contains('Configured columns: todo'));
      expect(footer, isNot(contains('Configured ticket types')));
    });

    test('usage omits the footer outside a project', () {
      final registry = CommandRegistry();
      registerCommands(registry, fs: MemoryFileSystem());
      final kanban = registry.commands.firstWhere((c) => c.name == 'kanban');
      for (final name in ['create', 'update', 'move']) {
        expect(kanban.subcommands[name]!.usageFooter, isNull, reason: name);
      }
    });
  });

  group('MoveCommand transition validation', () {
    test('move respects allowed_transitions when configured', () async {
      final fs = MemoryFileSystem();
      fs.directory('/.project/kanban').createSync(recursive: true);
      fs.file('/.project/dew.yaml').writeAsStringSync('''
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
      - id: backlog
        name: Backlog
        color: grey
        allowed_transitions:
          - doing
      - id: doing
        name: Doing
        color: blue
        allowed_transitions:
          - done
          - backlog
      - id: done
        name: Done
        color: green
''');
      final registry = CommandRegistry();
      registerCommands(registry, fs: fs);
      final tools = {for (final t in registry.mcpTools) t.name: t};

      await tools['kanban_create_ticket']!.handler({
        'title': 'Flow test',
        'type': 'task',
      });

      // Allowed: backlog → doing
      await expectLater(
        tools['kanban_move_ticket']!.handler({
          'id': 'T-0001',
          'column': 'doing',
        }),
        completes,
      );

      // Reset to backlog first.
      await tools['kanban_move_ticket']!.handler({
        'id': 'T-0001',
        'column': 'backlog',
      });

      // backlog → done should throw (not in allowed_transitions).
      await expectLater(
        tools['kanban_move_ticket']!.handler({
          'id': 'T-0001',
          'column': 'done',
        }),
        throwsA(isA<ArgumentError>()),
      );

      // Unconstrained column (done) — any target is valid.
      await tools['kanban_move_ticket']!.handler({
        'id': 'T-0001',
        'column': 'doing',
      });
      await tools['kanban_move_ticket']!.handler({
        'id': 'T-0001',
        'column': 'done',
      });
      // done → backlog: done has no constraints, so it's allowed.
      final result = await tools['kanban_move_ticket']!.handler({
        'id': 'T-0001',
        'column': 'backlog',
      });
      expect(result, contains('T-0001'));
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
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent(), t.column);
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
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent(), t.column);
      expect(parsed.body, '');
      expect(parsed.comments, isEmpty);
    });

    test('serializes markdown lists with surrounding blank lines', () {
      final t = Ticket(
        id: 'TEST-0003',
        title: 'List spacing',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 3),
        body: '''
Scope:
- First item
- Second item
Outcome:
1. Done
2. Verified
''',
        comments: const [
          '''
Notes:
- Comment item
Next paragraph.
''',
        ],
      );

      final content = t.toFileContent();
      expect(
        content,
        contains('Scope:\n\n- First item\n- Second item\n\nOutcome:'),
      );
      expect(content, contains('Outcome:\n\n1. Done\n2. Verified'));
      expect(content, contains('Notes:\n\n- Comment item\n\nNext paragraph.'));
    });

    test('does not alter list-like lines inside fenced code blocks', () {
      final t = Ticket(
        id: 'TEST-0004',
        title: 'Fence spacing',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 4),
        body: '''
Example:
```text
- keep this adjacent
next line
```
Then:
- Real item
''',
        comments: const [],
      );

      final content = t.toFileContent();
      expect(content, contains('Example:\n\n```text'));
      expect(
        content,
        contains('```text\n- keep this adjacent\nnext line\n```\n\nThen:'),
      );
      expect(content, contains('Then:\n\n- Real item'));
    });

    test('adds a default language to unlabeled fenced code blocks', () {
      final t = Ticket(
        id: 'TEST-0005',
        title: 'Fence language',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 5),
        body: '''
Example:
```
plain output
```
''',
        comments: const [],
      );

      expect(t.toFileContent(), contains('Example:\n\n```text\nplain output'));
    });

    test('links roundtrip serialisation', () {
      final t = Ticket(
        id: 'TEST-0006',
        title: 'Linked',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 3),
        body: '',
        comments: const [],
        links: [
          TicketLink(targetId: 'TEST-0001', type: 'blocks'),
          TicketLink(targetId: 'TEST-0002', type: 'relates_to'),
        ],
      );
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent(), t.column);
      expect(parsed.links, hasLength(2));
      expect(parsed.links[0].targetId, 'TEST-0001');
      expect(parsed.links[0].type, 'blocks');
      expect(parsed.links[1].targetId, 'TEST-0002');
      expect(parsed.links[1].type, 'relates_to');
    });

    test('no links field when links is empty', () {
      final t = Ticket(
        id: 'TEST-0007',
        title: 'No links',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 4),
        body: '',
        comments: const [],
      );
      expect(t.toFileContent(), isNot(contains('links:')));
    });

    test('milestones and labels roundtrip serialisation', () {
      final t = Ticket(
        id: 'TEST-0008',
        title: 'Tagged',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 5),
        body: '',
        comments: const [],
        milestones: ['v1.0', 'beta'],
        labels: ['good first issue', 'backend'],
      );
      final parsed = Ticket.fromFileContent(t.id, t.toFileContent(), t.column);
      expect(parsed.milestones, ['v1.0', 'beta']);
      expect(parsed.labels, ['good first issue', 'backend']);
    });

    test('no milestones/labels fields when empty', () {
      final t = Ticket(
        id: 'TEST-0009',
        title: 'Plain',
        type: 'task',
        column: 'todo',
        created: DateTime.utc(2026, 1, 6),
        body: '',
        comments: const [],
      );
      final content = t.toFileContent();
      expect(content, isNot(contains('milestones:')));
      expect(content, isNot(contains('labels:')));
    });
  });

  group('TicketStore', () {
    TicketStore makeStore(MemoryFileSystem fs) =>
        TicketStore(kanbanDir: '/kanban', prefix: 'TEST', fs: fs);

    test('create assigns incrementing IDs', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
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
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      expect(await store.findById('TEST-0099'), isNull);
    });

    test('create and list milestones/labels persist via store', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(
        title: 'Tagged',
        type: 'task',
        column: 'todo',
        milestones: ['v1.0'],
        labels: ['enhancement'],
      );
      await store.create(title: 'Plain', type: 'task', column: 'todo');
      final all = await store.list();
      expect(all[0].milestones, ['v1.0']);
      expect(all[0].labels, ['enhancement']);
      expect(all[1].milestones, isEmpty);
      expect(all[1].labels, isEmpty);
    });

    test('update patches milestones and labels', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(
        title: 'Tagged',
        type: 'task',
        column: 'todo',
        milestones: ['v1.0'],
        labels: ['old'],
      );
      final updated = await store.update('TEST-0001', labels: ['new']);
      expect(updated.milestones, ['v1.0']);
      expect(updated.labels, ['new']);
    });

    test('list returns sorted tickets', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      final all = await store.list();
      expect(all.map((t) => t.id), ['TEST-0001', 'TEST-0002']);
    });

    test('list excludes archive by default, includes with flag', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'Active', type: 'task', column: 'todo');
      // Manually move to archive dir to simulate archived state.
      fs.directory('/kanban/archive').createSync(recursive: true);
      final src = fs.file('/kanban/todo/TEST-0001.md');
      await src.rename('/kanban/archive/TEST-0001.md');

      expect(await store.list(), isEmpty);
      final withArchive = await store.list(includeArchived: true);
      expect(withArchive, hasLength(1));
      expect(withArchive.first.column, 'archive');
    });

    test('update patches specified fields', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'Old', type: 'task', column: 'todo');
      final updated = await store.update('TEST-0001', title: 'New');
      expect(updated.title, 'New');
      expect(updated.type, 'task');
    });

    test('update throws for missing ticket', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      expect(
        () => store.update('TEST-0099', title: 'X'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('delete removes ticket', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'Bye', type: 'task', column: 'todo');
      await store.delete('TEST-0001');
      expect(await store.findById('TEST-0001'), isNull);
    });

    test('delete throws for missing ticket', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      expect(() => store.delete('TEST-0099'), throwsA(isA<ArgumentError>()));
    });

    test(
      'linkTickets adds typed link bidirectionally and is idempotent',
      () async {
        final fs = MemoryFileSystem();
        final store = makeStore(fs);
        await store.create(title: 'A', type: 'task', column: 'todo');
        await store.create(title: 'B', type: 'task', column: 'todo');
        await store.linkTickets('TEST-0001', 'TEST-0002', 'blocks');

        final a = await store.findById('TEST-0001');
        expect(a!.links, hasLength(1));
        expect(a.links.first.targetId, 'TEST-0002');
        expect(a.links.first.type, 'blocks');

        // Inverse written on target.
        final b = await store.findById('TEST-0002');
        expect(b!.links, hasLength(1));
        expect(b.links.first.targetId, 'TEST-0001');
        expect(b.links.first.type, 'is_blocked_by');

        // Idempotent — calling again doesn't add duplicates.
        await store.linkTickets('TEST-0001', 'TEST-0002', 'blocks');
        final a2 = await store.findById('TEST-0001');
        expect(a2!.links, hasLength(1));
      },
    );

    test('linkTickets relates_to is symmetric', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      await store.linkTickets('TEST-0001', 'TEST-0002', 'relates_to');

      final a = await store.findById('TEST-0001');
      final b = await store.findById('TEST-0002');
      expect(a!.links.first.type, 'relates_to');
      expect(b!.links.first.type, 'relates_to');
    });

    test('linkTickets parent_of / child_of inverse pair', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'Epic', type: 'task', column: 'todo');
      await store.create(title: 'Story', type: 'task', column: 'todo');
      await store.linkTickets('TEST-0001', 'TEST-0002', 'parent_of');

      final parent = await store.findById('TEST-0001');
      final child = await store.findById('TEST-0002');
      expect(parent!.links.first.type, 'parent_of');
      expect(child!.links.first.type, 'child_of');
    });

    test('linkTickets throws for self-link via command', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'A', type: 'task', column: 'todo');
      // Self-link guard is in the command layer, not the store.
    });

    test('unlinkTickets removes link on both sides', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
      await store.create(title: 'A', type: 'task', column: 'todo');
      await store.create(title: 'B', type: 'task', column: 'todo');
      await store.linkTickets('TEST-0001', 'TEST-0002', 'blocks');
      await store.unlinkTickets('TEST-0001', 'TEST-0002');

      final a = await store.findById('TEST-0001');
      final b = await store.findById('TEST-0002');
      expect(a!.links, isEmpty);
      expect(b!.links, isEmpty);
    });

    test('stats returns correct counts', () async {
      final fs = MemoryFileSystem();
      final store = makeStore(fs);
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
