import 'package:yaml/yaml.dart';

class Ticket {
  final String id;
  final String title;
  final String type;
  final String column;
  final DateTime created;
  final String body;
  final List<String> comments;

  const Ticket({
    required this.id,
    required this.title,
    required this.type,
    required this.column,
    required this.created,
    required this.body,
    required this.comments,
  });

  Ticket copyWith({
    String? title,
    String? type,
    String? column,
    String? body,
    List<String>? comments,
  }) => Ticket(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    column: column ?? this.column,
    created: created,
    body: body ?? this.body,
    comments: comments ?? this.comments,
  );

  /// Serialises the ticket to markdown with YAML frontmatter.
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
    buf.writeln('title: $title');
    buf.writeln('type: $type');
    buf.writeln('column: $column');
    buf.writeln('created: ${created.toUtc().toIso8601String()}');
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

  static Ticket fromFileContent(String id, String content) {
    if (!content.startsWith('---\n')) {
      throw FormatException('Ticket file $id does not start with ---');
    }
    final fmEnd = content.indexOf('\n---\n', 4);
    if (fmEnd == -1) {
      throw FormatException('Ticket file $id is missing closing frontmatter ---');
    }

    final fm = loadYaml(content.substring(4, fmEnd)) as YamlMap;

    // Everything after the closing \n---\n, split into body + comments.
    final rest = content.substring(fmEnd + 5);
    final sections =
        rest.split('\n---\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return Ticket(
      id: id,
      title: fm['title'] as String,
      type: fm['type'] as String,
      column: fm['column'] as String,
      created: DateTime.parse(fm['created'] as String),
      body: sections.isNotEmpty ? sections[0] : '',
      comments: sections.length > 1 ? sections.sublist(1) : const [],
    );
  }
}
