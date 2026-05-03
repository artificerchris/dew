import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class ListCommand extends DewCommand with DewToolCommand {
  ListCommand() {
    argParser.addOption(
      'format',
      defaultsTo: 'default',
      allowed: ['default', 'json'],
      help: 'Output format for this command.',
    );
  }

  @override
  final String name = 'list';

  @override
  final String description = 'List vault secrets.';

  @override
  final String toolName = 'vault_list_secrets';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    return renderVaultOutput(
      format: format,
      message: 'No secrets found (stubbed vault).',
      json: {'secrets': <String>[], 'count': 0},
    );
  }

}
