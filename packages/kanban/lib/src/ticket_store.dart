import 'dart:io';

import 'package:path/path.dart' as p;

import 'ticket.dart';

class TicketStore {
  final String kanbanDir;
  final String prefix;

  const TicketStore({required this.kanbanDir, required this.prefix});

  Future<Ticket> create({
    required String title,
    required String type,
    required String column,
    String body = '',
  }) async {
    await Directory(kanbanDir).create(recursive: true);
    final id = _formatId(await _nextNumber());
    final ticket = Ticket(
      id: id,
      title: title,
      type: type,
      column: column,
      created: DateTime.now().toUtc(),
      body: body,
      comments: const [],
    );
    await File(_filePath(id)).writeAsString(ticket.toFileContent());
    return ticket;
  }

  Future<Ticket?> findById(String id) async {
    final file = File(_filePath(id));
    if (!await file.exists()) return null;
    return Ticket.fromFileContent(id, await file.readAsString());
  }

  Future<List<Ticket>> list() async {
    final dir = Directory(kanbanDir);
    if (!await dir.exists()) return const [];
    final pattern = RegExp(r'^' + RegExp.escape(prefix) + r'-\d{4}\.md$');
    final tickets = <Ticket>[];
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (pattern.hasMatch(name)) {
        final id = p.basenameWithoutExtension(name);
        final ticket = await findById(id);
        if (ticket != null) tickets.add(ticket);
      }
    }
    tickets.sort((a, b) => a.id.compareTo(b.id));
    return tickets;
  }

  Future<Ticket> addComment(String id, String comment) async {
    final ticket = await findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    final updated = ticket.copyWith(
      comments: [...ticket.comments, comment],
    );
    await File(_filePath(id)).writeAsString(updated.toFileContent());
    return updated;
  }

  Future<Ticket> update(
    String id, {
    String? title,
    String? type,
    String? column,
    String? body,
  }) async {
    final ticket = await findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    final updated = ticket.copyWith(
      title: title,
      type: type,
      column: column,
      body: body,
    );
    await File(_filePath(id)).writeAsString(updated.toFileContent());
    return updated;
  }

  Future<void> delete(String id) async {
    final file = File(_filePath(id));
    if (!await file.exists()) throw ArgumentError('Ticket $id not found.');
    await file.delete();
  }

  Future<int> _nextNumber() async {
    final dir = Directory(kanbanDir);
    if (!await dir.exists()) return 1;
    final pattern = RegExp(r'^' + RegExp.escape(prefix) + r'-(\d+)\.md$');
    var max = 0;
    await for (final entity in dir.list()) {
      final match = pattern.firstMatch(p.basename(entity.path));
      if (match != null) {
        final n = int.parse(match.group(1)!);
        if (n > max) max = n;
      }
    }
    return max + 1;
  }

  String _formatId(int n) => '$prefix-${n.toString().padLeft(4, '0')}';

  String _filePath(String id) => p.join(kanbanDir, '$id.md');
}
