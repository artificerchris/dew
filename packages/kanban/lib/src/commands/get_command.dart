import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket.dart';
import '../ticket_store.dart';

class GetCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  GetCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser.addOption(
      'id',
      abbr: 'i',
      mandatory: true,
      help: 'Ticket ID (e.g. DEW-0001).',
    );
  }

  @override
  final String name = 'get';

  @override
  final String description = 'Get a kanban ticket by ID.';

  @override
  final String toolName = 'kanban_get_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = '${args['id']}'.toUpperCase();
    final context = await ProjectContext.find(fs: _fs);
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: context.config.kanban.prefix,
      fs: context.fs,
    );
    final ticket = await store.findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    return _format(ticket);
  }

  String _format(Ticket t) {
    final buf = StringBuffer();
    buf.writeln('[${t.id}] (${t.type}) [${t.column}] ${t.title}');
    buf.writeln('Created: ${t.created.toLocal().toString().split('.').first}');
    if (t.milestones.isNotEmpty) {
      buf.writeln('Milestones: ${t.milestones.join(', ')}');
    }
    if (t.labels.isNotEmpty) {
      buf.writeln('Labels: ${t.labels.join(', ')}');
    }
    if (t.links.isNotEmpty) {
      buf.writeln();
      buf.writeln('Links:');
      for (final link in t.links) {
        buf.writeln('  ${link.type.replaceAll('_', ' ')}: ${link.targetId}');
      }
    }
    if (t.body.isNotEmpty) {
      buf.writeln();
      buf.writeln(t.body);
    }
    for (final (i, comment) in t.comments.indexed) {
      buf.writeln();
      buf.writeln('── Comment ${i + 1} ${'─' * 20}');
      buf.write(comment);
    }
    return buf.toString().trimRight();
  }
}
