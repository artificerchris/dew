import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

import 'ticket.dart';
import 'ticket_store.dart';

/// Exposes Kanban board operations as MCP tools.
class KanbanToolProvider implements McpToolProvider {
  @override
  List<McpTool> get tools => [
    McpTool(
      name: 'kanban_create_ticket',
      description: 'Create a new kanban ticket.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Ticket title.'},
          'type': {
            'type': 'string',
            'description': 'Ticket type (e.g. task, bug).',
          },
          'column': {
            'type': 'string',
            'description':
                'Initial column. Defaults to the first configured column.',
          },
          'body': {'type': 'string', 'description': 'Ticket description.'},
        },
        'required': ['title', 'type'],
      },
      handler: _createTicket,
    ),
    McpTool(
      name: 'kanban_list_tickets',
      description: 'List kanban tickets, optionally filtered by column or type.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'column': {
            'type': 'string',
            'description': 'Filter to tickets in this column.',
          },
          'type': {
            'type': 'string',
            'description': 'Filter to tickets of this type.',
          },
        },
      },
      handler: _listTickets,
    ),
    McpTool(
      name: 'kanban_get_ticket',
      description: 'Get a kanban ticket by ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Ticket ID (e.g. DEW-0001).',
          },
        },
        'required': ['id'],
      },
      handler: _getTicket,
    ),
    McpTool(
      name: 'kanban_update_ticket',
      description: 'Update one or more fields on an existing kanban ticket.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Ticket ID.'},
          'title': {'type': 'string', 'description': 'New title.'},
          'type': {'type': 'string', 'description': 'New ticket type.'},
          'column': {'type': 'string', 'description': 'New column.'},
          'body': {
            'type': 'string',
            'description': 'New body (replaces existing body).',
          },
        },
        'required': ['id'],
      },
      handler: _updateTicket,
    ),
    McpTool(
      name: 'kanban_delete_ticket',
      description: 'Delete a kanban ticket by ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Ticket ID.'},
        },
        'required': ['id'],
      },
      handler: _deleteTicket,
    ),
  ];

  Future<TicketStore> _store() async {
    final context = await ProjectContext.find();
    return TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: context.config.kanban.prefix,
    );
  }

  Future<String> _createTicket(Map<String, dynamic> args) async {
    final context = await ProjectContext.find();
    final config = context.config.kanban;
    final title = args['title'] as String;
    final typeId = args['type'] as String;
    final column = args['column'] as String? ?? config.columns.first.id;
    final body = args['body'] as String? ?? '';

    if (!config.ticketTypes.any((t) => t.id == typeId)) {
      throw ArgumentError(
        'Unknown type "$typeId". Valid: ${config.ticketTypes.map((t) => t.id).join(', ')}',
      );
    }
    if (!config.columns.any((c) => c.id == column)) {
      throw ArgumentError(
        'Unknown column "$column". Valid: ${config.columns.map((c) => c.id).join(', ')}',
      );
    }

    final store = TicketStore(
      kanbanDir: p.join(context.root, '.project', 'kanban'),
      prefix: config.prefix,
    );
    final ticket = await store.create(
      title: title,
      type: typeId,
      column: column,
      body: body,
    );
    return 'Created ${ticket.id}: ${ticket.title}';
  }

  Future<String> _listTickets(Map<String, dynamic> args) async {
    final columnFilter = args['column'] as String?;
    final typeFilter = args['type'] as String?;
    final store = await _store();
    var tickets = await store.list();

    if (columnFilter != null) {
      tickets = tickets.where((t) => t.column == columnFilter).toList();
    }
    if (typeFilter != null) {
      tickets = tickets.where((t) => t.type == typeFilter).toList();
    }

    if (tickets.isEmpty) return 'No tickets found.';

    return tickets
        .map((t) => '[${t.id}] (${t.type}) [${t.column}] ${t.title}')
        .join('\n');
  }

  Future<String> _getTicket(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final store = await _store();
    final ticket = await store.findById(id);
    if (ticket == null) throw ArgumentError('Ticket $id not found.');
    return _formatTicket(ticket);
  }

  Future<String> _updateTicket(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final store = await _store();
    final updated = await store.update(
      id,
      title: args['title'] as String?,
      type: args['type'] as String?,
      column: args['column'] as String?,
      body: args['body'] as String?,
    );
    return 'Updated ${updated.id}.\n${_formatTicket(updated)}';
  }

  Future<String> _deleteTicket(Map<String, dynamic> args) async {
    final id = (args['id'] as String).toUpperCase();
    final store = await _store();
    await store.delete(id);
    return 'Deleted $id.';
  }

  String _formatTicket(Ticket t) {
    final buf = StringBuffer();
    buf.writeln('[${t.id}] (${t.type}) [${t.column}] ${t.title}');
    buf.writeln(
      'Created: ${t.created.toLocal().toString().split('.').first}',
    );
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
