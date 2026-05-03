import 'dart:convert';

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
