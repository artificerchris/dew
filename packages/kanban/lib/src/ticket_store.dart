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

  Future<Ticket> linkTickets(String id, String targetId, String type) async {
    if (!linkTypeInverses.containsKey(type)) {
      throw ArgumentError(
        'Unknown link type "$type". '
        'Valid: ${linkTypeInverses.keys.join(', ')}',
      );
    }
    final ticket = await findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    final target = await findById(targetId);
    if (target == null) throw ArgumentError('Ticket $targetId not found.');

    // Forward link (idempotent — skip if already linked to same target).
    if (!ticket.links.any((l) => l.targetId == targetId)) {
      final updated = ticket.copyWith(
        links: [...ticket.links, TicketLink(targetId: targetId, type: type)],
      );
      await File(_filePath(id)).writeAsString(updated.toFileContent());
    }

    // Inverse link on the target.
    final inverseType = linkTypeInverses[type]!;
    if (!target.links.any((l) => l.targetId == id)) {
      final updatedTarget = target.copyWith(
        links: [...target.links, TicketLink(targetId: id, type: inverseType)],
      );
      await File(_filePath(targetId)).writeAsString(updatedTarget.toFileContent());
    }

    return (await findById(id))!;
  }

  Future<Ticket> unlinkTickets(String id, String targetId) async {
    final ticket = await findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');

    // Remove forward link.
    final updated = ticket.copyWith(
      links: ticket.links.where((l) => l.targetId != targetId).toList(),
    );
    await File(_filePath(id)).writeAsString(updated.toFileContent());

    // Remove inverse link on target (if it exists).
    final target = await findById(targetId);
    if (target != null) {
      final updatedTarget = target.copyWith(
        links: target.links.where((l) => l.targetId != id).toList(),
      );
      await File(_filePath(targetId)).writeAsString(updatedTarget.toFileContent());
    }

    return (await findById(id))!;
  }

  /// Returns counts of tickets grouped by column and type.
  Future<Map<String, dynamic>> stats() async {
    final tickets = await list();
    final byColumn = <String, int>{};
    final byType = <String, int>{};
    for (final t in tickets) {
      byColumn[t.column] = (byColumn[t.column] ?? 0) + 1;
      byType[t.type] = (byType[t.type] ?? 0) + 1;
    }
    return {'total': tickets.length, 'byColumn': byColumn, 'byType': byType};
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
