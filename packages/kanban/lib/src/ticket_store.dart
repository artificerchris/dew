import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'ticket.dart';

class TicketStore {
  final String kanbanDir;
  final String prefix;
  final FileSystem fs;

  /// Provides the current time for ticket creation. Injectable for testing.
  final DateTime Function() clock;

  const TicketStore({
    required this.kanbanDir,
    required this.prefix,
    this.fs = const LocalFileSystem(),
    this.clock = DateTime.now,
  });

  Future<Ticket> create({
    required String title,
    required String type,
    required String column,
    String body = '',
    List<String> milestones = const [],
    List<String> labels = const [],
  }) async {
    final columnDir = fs.directory(p.join(kanbanDir, column));
    await columnDir.create(recursive: true);
    final id = _formatId(await _nextNumber());
    final ticket = Ticket(
      id: id,
      title: title,
      type: type,
      column: column,
      created: clock().toUtc(),
      body: body,
      comments: const [],
      milestones: milestones,
      labels: labels,
    );
    await fs
        .file(p.join(columnDir.path, '$id.md'))
        .writeAsString(ticket.toFileContent());
    return ticket;
  }

  Future<Ticket?> findById(String id) async {
    final found = await _findTicketFile(id);
    if (found == null) return null;
    return Ticket.fromFileContent(
      id,
      await found.file.readAsString(),
      found.column,
    );
  }

  Future<List<Ticket>> list({bool includeArchived = false}) async {
    final dir = fs.directory(kanbanDir);
    if (!await dir.exists()) return const [];
    final pattern = RegExp(r'^' + RegExp.escape(prefix) + r'-\d{4}\.md$');
    final tickets = <Ticket>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final col = p.basename(entity.path);
      if (col == 'attachments') continue;
      if (col == 'archive' && !includeArchived) continue;
      await for (final file in entity.list()) {
        if (file is! File) continue;
        final name = p.basename(file.path);
        if (!pattern.hasMatch(name)) continue;
        final id = p.basenameWithoutExtension(name);
        tickets.add(Ticket.fromFileContent(id, await file.readAsString(), col));
      }
    }
    tickets.sort((a, b) => a.id.compareTo(b.id));
    return tickets;
  }

  Future<Ticket> addComment(String id, String comment) async {
    final found = await _findTicketFile(id);
    if (found == null) throw ArgumentError('Ticket $id not found.');
    final ticket = Ticket.fromFileContent(
      id,
      await found.file.readAsString(),
      found.column,
    );
    final updated = ticket.copyWith(comments: [...ticket.comments, comment]);
    await found.file.writeAsString(updated.toFileContent());
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
        links: [
          ...ticket.links,
          TicketLink(targetId: targetId, type: type),
        ],
      );
      final found = (await _findTicketFile(id))!;
      await found.file.writeAsString(updated.toFileContent());
    }

    // Inverse link on the target.
    final inverseType = linkTypeInverses[type]!;
    if (!target.links.any((l) => l.targetId == id)) {
      final updatedTarget = target.copyWith(
        links: [
          ...target.links,
          TicketLink(targetId: id, type: inverseType),
        ],
      );
      final foundTarget = (await _findTicketFile(targetId))!;
      await foundTarget.file.writeAsString(updatedTarget.toFileContent());
    }

    return (await findById(id))!;
  }

  Future<Ticket> unlinkTickets(String id, String targetId) async {
    final found = await _findTicketFile(id);
    if (found == null) throw ArgumentError('Ticket $id not found.');
    final ticket = Ticket.fromFileContent(
      id,
      await found.file.readAsString(),
      found.column,
    );
    final updated = ticket.copyWith(
      links: ticket.links.where((l) => l.targetId != targetId).toList(),
    );
    await found.file.writeAsString(updated.toFileContent());

    // Remove inverse link on target (if it exists).
    final foundTarget = await _findTicketFile(targetId);
    if (foundTarget != null) {
      final target = Ticket.fromFileContent(
        targetId,
        await foundTarget.file.readAsString(),
        foundTarget.column,
      );
      final updatedTarget = target.copyWith(
        links: target.links.where((l) => l.targetId != id).toList(),
      );
      await foundTarget.file.writeAsString(updatedTarget.toFileContent());
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
    List<String>? milestones,
    List<String>? labels,
  }) async {
    final found = await _findTicketFile(id);
    if (found == null) throw ArgumentError('Ticket $id not found.');
    final ticket = Ticket.fromFileContent(
      id,
      await found.file.readAsString(),
      found.column,
    );
    final updated = ticket.copyWith(
      title: title,
      type: type,
      column: column,
      body: body,
      milestones: milestones,
      labels: labels,
    );
    if (column != null && column != ticket.column) {
      // Column changed — move the file to the new column directory.
      await found.file.delete();
      final newColDir = fs.directory(p.join(kanbanDir, column));
      await newColDir.create(recursive: true);
      await fs
          .file(p.join(newColDir.path, '$id.md'))
          .writeAsString(updated.toFileContent());
    } else {
      await found.file.writeAsString(updated.toFileContent());
    }
    return updated;
  }

  Future<void> delete(String id) async {
    final found = await _findTicketFile(id);
    if (found == null) throw ArgumentError('Ticket $id not found.');
    await found.file.delete();
    // Clean up per-ticket attachment directory if present.
    final attachmentsDir = fs.directory(p.join(kanbanDir, 'attachments', id));
    if (await attachmentsDir.exists()) {
      await attachmentsDir.delete(recursive: true);
    }
  }

  /// Searches all column subdirectories (one level deep) for a ticket file.
  /// Skips the [attachments] directory. Includes [archive].
  Future<({File file, String column})?> _findTicketFile(String id) async {
    final dir = fs.directory(kanbanDir);
    if (!await dir.exists()) return null;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      if (p.basename(entity.path) == 'attachments') continue;
      final file = fs.file(p.join(entity.path, '$id.md'));
      if (await file.exists()) {
        return (file: file, column: p.basename(entity.path));
      }
    }
    return null;
  }

  Future<int> _nextNumber() async {
    final dir = fs.directory(kanbanDir);
    if (!await dir.exists()) return 1;
    final pattern = RegExp(r'^' + RegExp.escape(prefix) + r'-(\d+)\.md$');
    var max = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory || p.basename(entity.path) == 'attachments') {
        continue;
      }
      await for (final file in entity.list()) {
        final match = pattern.firstMatch(p.basename(file.path));
        if (match != null) {
          final n = int.parse(match.group(1)!);
          if (n > max) max = n;
        }
      }
    }
    return max + 1;
  }

  String _formatId(int n) => '$prefix-${n.toString().padLeft(4, '0')}';
}
