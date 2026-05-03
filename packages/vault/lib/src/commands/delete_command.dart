import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class DeleteCommand extends DewCommand with DewToolCommand {
  DeleteCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        mandatory: true,
        help: 'Secret name.',
      )
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'delete';

  @override
  final String description = 'Delete a secret.';

  @override
  final String toolName = 'vault_delete_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final secretName = requireStringArg(args, 'name');
    return renderVaultOutput(
      format: format,
      message: 'Delete stub executed.',
      json: {'secret': secretName},
    );
  }

}
