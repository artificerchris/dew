import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import '../kanban_config.dart';

import '../ticket_store.dart';

class UpdateCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  UpdateCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('id', abbr: 'i', mandatory: true, help: 'Ticket ID.')
      ..addOption('title', abbr: 't', help: 'New title.')
      ..addOption('type', help: 'New ticket type.')
      ..addOption('column', abbr: 'c', help: 'New column.')
      ..addOption('body', abbr: 'b', help: 'New body (replaces existing body).')
      ..addMultiOption(
        'milestone',
        help: 'Replace milestone list (repeatable; omit to leave unchanged).',
      )
      ..addMultiOption(
        'label',
        help: 'Replace label list (repeatable; omit to leave unchanged).',
      );
  }

  @override
  final String name = 'update';

  @override
  final String description =
      'Update one or more fields on an existing kanban ticket.';

  @override
  final String toolName = 'kanban_update_ticket';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final id = '${args['id']}'.toUpperCase();
    final title = args['title'] != null ? '${args['title']}' : null;
    final typeId = args['type'] != null ? '${args['type']}' : null;
    final column = args['column'] != null ? '${args['column']}' : null;
    final body = args['body'] != null ? '${args['body']}' : null;
    final rawMilestones = args['milestone'] as List?;
    final milestones = rawMilestones != null && rawMilestones.isNotEmpty
        ? rawMilestones.cast<String>().where((s) => s.isNotEmpty).toList()
        : null;
    final rawLabels = args['label'] as List?;
    final labels = rawLabels != null && rawLabels.isNotEmpty
        ? rawLabels.cast<String>().where((s) => s.isNotEmpty).toList()
        : null;

    if (title == null &&
        typeId == null &&
        column == null &&
        body == null &&
        milestones == null &&
        labels == null) {
      throw ArgumentError(
        'At least one of --title, --type, --column, --body, --milestone, --label must be specified.',
      );
    }

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;

    if (typeId != null && !config.ticketTypes.any((t) => t.id == typeId)) {
      throw ArgumentError(
        'Unknown type "$typeId". '
        'Valid: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }
    if (column != null && !config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". '
        'Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: config.prefix,
      fs: context.fs,
    );
    final ticket = await store.update(
      id,
      title: title,
      type: typeId,
      column: column,
      body: body,
      milestones: milestones,
      labels: labels,
    );
    return 'Updated ${ticket.id}.';
  }
}
