import 'package:yaml/yaml.dart';

/// The valid relationship types between tickets, and their inverses.
const Map<String, String> linkTypeInverses = {
  'blocks': 'is_blocked_by',
  'is_blocked_by': 'blocks',
  'relates_to': 'relates_to',
  'duplicates': 'is_duplicated_by',
  'is_duplicated_by': 'duplicates',
  'parent_of': 'child_of',
  'child_of': 'parent_of',
};

/// A typed, directed link from one ticket to another.
class TicketLink {
  final String targetId;

  /// One of the keys in [linkTypeInverses].
  final String type;

  const TicketLink({required this.targetId, required this.type});

  @override
  bool operator ==(Object other) =>
      other is TicketLink && other.targetId == targetId && other.type == type;

  @override
  int get hashCode => Object.hash(targetId, type);
}

class Ticket {
  final String id;
  final String title;
  final String type;
  final String column;
  final DateTime created;
  final String body;
  final List<String> comments;
  final List<TicketLink> links;
  final List<String> milestones;
  final List<String> labels;

  const Ticket({
    required this.id,
    required this.title,
    required this.type,
    required this.column,
    required this.created,
    required this.body,
    required this.comments,
    this.links = const [],
    this.milestones = const [],
    this.labels = const [],
  });

  Ticket copyWith({
    String? title,
    String? type,
    String? column,
    String? body,
    List<String>? comments,
    List<TicketLink>? links,
    List<String>? milestones,
    List<String>? labels,
  }) => Ticket(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    column: column ?? this.column,
    created: created,
    body: body ?? this.body,
    comments: comments ?? this.comments,
    links: links ?? this.links,
    milestones: milestones ?? this.milestones,
    labels: labels ?? this.labels,
  );

  /// Serialises the ticket to markdown with YAML frontmatter.
  ///
  /// The column is intentionally omitted — it is derived from the containing
  /// directory name and would be redundant (and stale after a move).
  ///
  /// Format:
  /// ```
  /// ---
  /// id: DEW-0001
  /// title: My ticket
  /// ...
  /// ---
  ///
  /// Body text.
  ///
  /// ---
  ///
  /// Comment text.
  /// ```
  String toFileContent() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('id: $id');
    buf.writeln('title: ${_yamlQuote(title)}');
    buf.writeln('type: $type');
    buf.writeln('created: ${created.toUtc().toIso8601String()}');
    if (milestones.isNotEmpty) {
      buf.writeln('milestones:');
      for (final m in milestones) {
        buf.writeln('  - ${_yamlQuote(m)}');
      }
    }
    if (labels.isNotEmpty) {
      buf.writeln('labels:');
      for (final l in labels) {
        buf.writeln('  - ${_yamlQuote(l)}');
      }
    }
    if (links.isNotEmpty) {
      buf.writeln('links:');
      for (final link in links) {
        buf.writeln('  - id: ${link.targetId}');
        buf.writeln('    type: ${link.type}');
      }
    }
    buf.writeln('---');
    if (body.isNotEmpty) {
      buf.writeln();
      buf.writeln(body);
    }
    for (final comment in comments) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln(comment);
    }
    return buf.toString();
  }

  /// Parses a ticket from file content. [column] must be supplied by the
  /// caller (derived from the containing directory name).
  static Ticket fromFileContent(String id, String content, String column) {
    if (!content.startsWith('---\n')) {
      throw FormatException('Ticket file $id does not start with ---');
    }
    final fmEnd = content.indexOf('\n---\n', 4);
    if (fmEnd == -1) {
      throw FormatException(
        'Ticket file $id is missing closing frontmatter ---',
      );
    }

    final fm = loadYaml(content.substring(4, fmEnd)) as YamlMap;

    // Everything after the closing \n---\n, split into body + comments.
    final rest = content.substring(fmEnd + 5);
    final sections = rest
        .split('\n---\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final rawLinks = fm['links'] as YamlList?;
    final links =
        rawLinks?.map((entry) {
          final map = entry as YamlMap;
          return TicketLink(
            targetId: map['id'] as String,
            type: map['type'] as String,
          );
        }).toList() ??
        const [];

    List<String> parseStringList(String key) {
      final raw = fm[key] as YamlList?;
      return raw?.map((e) => e as String).toList() ?? const [];
    }

    return Ticket(
      id: id,
      title: fm['title'] as String,
      type: fm['type'] as String,
      column: column,
      created: DateTime.parse(fm['created'] as String),
      body: sections.isNotEmpty ? sections[0] : '',
      comments: sections.length > 1 ? sections.sublist(1) : const [],
      links: links,
      milestones: parseStringList('milestones'),
      labels: parseStringList('labels'),
    );
  }

  /// Wraps [value] in double quotes if it contains characters that would
  /// confuse a YAML parser (colon-space, leading/trailing whitespace, etc.).
  static String _yamlQuote(String value) {
    final needsQuoting =
        value.contains(': ') ||
        value.contains(' #') ||
        value.startsWith('"') ||
        value.startsWith("'") ||
        value.startsWith(' ') ||
        value.endsWith(' ');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
}
