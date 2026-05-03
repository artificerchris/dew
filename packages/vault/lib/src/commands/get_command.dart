import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class GetCommand extends DewCommand with DewToolCommand {
  GetCommand() {
    argParser
      ..addOption('name', abbr: 'n', mandatory: true, help: 'Secret name.')
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'get';

  @override
  final String description = 'Get a secret value.';

  @override
  final String toolName = 'vault_get_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final secretName = requireStringArg(args, 'name');
    return renderVaultOutput(
      format: format,
      message: 'Get stub value: [redacted].',
      json: {'secret': secretName},
    );
  }

}
