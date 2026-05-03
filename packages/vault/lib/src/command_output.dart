import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

String renderVaultOutput({
  String format = 'default',
  required String message,
  Map<String, dynamic>? json,
}) {
  if (format == 'json') {
    final payload = <String, dynamic>{
      'message': message,
      if (json != null) ...json,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
  return message;
}

String requireStringArg(Map<String, dynamic> args, String key) {
  final value = args[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw ArgumentError('Missing required argument: --$key');
  }
  return value.toString();
}

String formatFromArgs(Map<String, dynamic> args) {
  final value = args['format'];
  if (value == null || value.toString().trim().isEmpty) return 'default';
  return value.toString();
}

String resolveProjectPath(String projectRoot, String value) {
  return p.isAbsolute(value) ? value : p.join(projectRoot, value);
}

Future<String?> readSecretInput(
  Map<String, dynamic> args, {
  required FileSystem fs,
  bool required = true,
  bool allowStdin = true,
  String? projectRoot,
}) async {
  final envVar = args['env']?.toString();
  if (envVar != null && envVar.trim().isNotEmpty) {
    final envValue = Platform.environment[envVar];
    if (envValue == null || envValue.isEmpty) {
      throw ArgumentError(
        'Environment variable "$envVar" is not set or is empty.',
      );
    }
    return envValue;
  }

  final filePath = args['file']?.toString();
  if (filePath != null && filePath.trim().isNotEmpty) {
    final resolved = projectRoot == null
        ? filePath
        : resolveProjectPath(projectRoot, filePath);
    final value = await fs.file(resolved).readAsString();
    if (value.trim().isEmpty) {
      throw ArgumentError('File "$filePath" is empty.');
    }
    return value.trimRight();
  }

  if (!allowStdin || stdin.hasTerminal) {
    if (!required) return null;
    throw ArgumentError('Missing secret value. Use --env, --file, or pipe input.');
  }

  final input = (await stdin.transform(utf8.decoder).join()).trimRight();
  if (input.trim().isEmpty) {
    if (!required) return null;
    throw ArgumentError('Piped input was empty.');
  }
  return input;
}

Map<String, dynamic> mergeMetadata(
  Map<String, dynamic> base,
  Map<String, dynamic>? updates,
) {
  final merged = Map<String, dynamic>.from(base);
  if (updates == null) return merged;
  for (final entry in updates.entries) {
    merged[entry.key] = entry.value;
  }
  return merged;
}

Future<Map<String, dynamic>> parseMetadataFromArgs({
  required Map<String, dynamic> args,
  required FileSystem fs,
  String? projectRoot,
}) async {
  final inline = args['metadata']?.toString();
  final filePath = args['metadata-file']?.toString();

  if (inline != null && filePath != null) {
    throw ArgumentError('Use either --metadata or --metadata-file, not both.');
  }

  String raw = '';
  if (inline != null) {
    raw = inline;
  } else if (filePath != null) {
    final resolved = projectRoot == null ? filePath : resolveProjectPath(projectRoot, filePath);
    raw = await fs.file(resolved).readAsString();
  }
  if (raw.isEmpty) return {};

  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw ArgumentError('Metadata must be a JSON object.');
  }
  return Map<String, dynamic>.fromEntries(
    decoded.entries.map((e) => MapEntry(e.key.toString(), e.value)),
  );
}

Map<String, dynamic> parseGeneratorOptionPairs(dynamic value) {
  final values = <String, dynamic>{};
  final rawValues = switch (value) {
    List list => list,
    null => const [],
    dynamic single => [single],
  };

  for (final item in rawValues) {
    if (item == null) continue;
    final entry = item.toString();
    if (entry.trim().isEmpty) continue;
    final splitAt = entry.indexOf('=');
    final key = splitAt == -1
        ? entry.trim()
        : entry.substring(0, splitAt).trim();
    final rawValue = splitAt == -1 ? null : entry.substring(splitAt + 1);
    if (key.isEmpty) continue;
    values[key] = _coerceValue(rawValue?.trim());
  }
  return values;
}

dynamic _coerceValue(String? value) {
  if (value == null) return true;
  final lower = value.toLowerCase();
  if (lower == 'true') return true;
  if (lower == 'false') return false;
  if (int.tryParse(value) != null) return int.parse(value);
  if (double.tryParse(value) != null) return double.parse(value);
  if ((value.startsWith('{') && value.endsWith('}')) ||
      (value.startsWith('[') && value.endsWith(']'))) {
    try {
      return jsonDecode(value);
    } catch (_) {}
  }
  return value;
}
