import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class RotateCommand extends DewCommand with DewToolCommand {
  RotateCommand() {
    argParser
      ..addOption('name', help: 'Secret name to rotate; omit to rotate vault password.')
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'rotate';

  @override
  final String description =
      'Rotate vault password or a single secret value (stub).';

  @override
  final String toolName = 'vault_rotate_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final target = args['name']?.toString();
    return renderVaultOutput(
      format: format,
      message: 'Rotate stub executed.',
      json: {'target': target ?? '<all>', 'scope': target == null ? 'vault' : 'secret'},
    );
  }

}
