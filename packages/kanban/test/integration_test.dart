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
      - id: doing
        name: Doing
        color: yellow
      - id: done
        name: Done
        color: green
''';

TicketStore _makeStore(MemoryFileSystem fs) {
  fs.directory('/.project/kanban').createSync(recursive: true);
  fs.file('/.project/dew.yaml').writeAsStringSync(_testConfig);
  return TicketStore(kanbanDir: '/.project/kanban', prefix: 'T', fs: fs);
}

void main() {
  group('TicketStore integration', () {
    late MemoryFileSystem fs;
    late TicketStore store;

    setUp(() {
      fs = MemoryFileSystem();
      store = _makeStore(fs);
    });

    test(
      'create() writes file at correct path with YAML frontmatter',
      () async {
        final ticket = await store.create(
          title: 'My ticket',
          type: 'task',
          column: 'todo',
        );

        expect(ticket.id, 'T-0001');
        final file = fs.file('/.project/kanban/todo/T-0001.md');
        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('title: My ticket'));
        expect(content, contains('type: task'));
      },
    );

    test('list() returns ticket created via create()', () async {
      await store.create(title: 'Alpha', type: 'task', column: 'todo');
      final tickets = await store.list();
      expect(tickets, hasLength(1));
      expect(tickets.first.id, 'T-0001');
      expect(tickets.first.title, 'Alpha');
    });

    test('update(column:) moves ticket to correct directory', () async {
      await store.create(title: 'Move me', type: 'task', column: 'todo');

      await store.update('T-0001', column: 'doing');

      // File removed from old location.
      expect(
        await fs.file('/.project/kanban/todo/T-0001.md').exists(),
        isFalse,
      );
      // File present in new location.
      expect(
        await fs.file('/.project/kanban/doing/T-0001.md').exists(),
        isTrue,
      );

      final ticket = await store.findById('T-0001');
      expect(ticket!.column, 'doing');
    });

    test('linkTickets() adds link to both ticket files', () async {
      await store.create(title: 'Source', type: 'task', column: 'todo');
      await store.create(title: 'Target', type: 'task', column: 'todo');

      await store.linkTickets('T-0001', 'T-0002', 'relates_to');

      final sourceContent = await fs
          .file('/.project/kanban/todo/T-0001.md')
          .readAsString();
      final targetContent = await fs
          .file('/.project/kanban/todo/T-0002.md')
          .readAsString();

      expect(sourceContent, contains('T-0002'));
      expect(targetContent, contains('T-0001'));

      final source = await store.findById('T-0001');
      final target = await store.findById('T-0002');
      expect(source!.links.any((l) => l.targetId == 'T-0002'), isTrue);
      expect(target!.links.any((l) => l.targetId == 'T-0001'), isTrue);
    });

    test('unlinkTickets() removes link from both ticket files', () async {
      await store.create(title: 'Source', type: 'task', column: 'todo');
      await store.create(title: 'Target', type: 'task', column: 'todo');
      await store.linkTickets('T-0001', 'T-0002', 'relates_to');

      await store.unlinkTickets('T-0001', 'T-0002');

      final source = await store.findById('T-0001');
      final target = await store.findById('T-0002');
      expect(source!.links, isEmpty);
      expect(target!.links, isEmpty);

      final sourceContent = await fs
          .file('/.project/kanban/todo/T-0001.md')
          .readAsString();
      final targetContent = await fs
          .file('/.project/kanban/todo/T-0002.md')
          .readAsString();
      expect(sourceContent, isNot(contains('T-0002')));
      expect(targetContent, isNot(contains('T-0001')));
    });

    test('delete() removes ticket file from disk', () async {
      await store.create(title: 'Doomed', type: 'task', column: 'todo');
      expect(await fs.file('/.project/kanban/todo/T-0001.md').exists(), isTrue);

      await store.delete('T-0001');

      expect(
        await fs.file('/.project/kanban/todo/T-0001.md').exists(),
        isFalse,
      );
      expect(await store.findById('T-0001'), isNull);
    });
  });
}
