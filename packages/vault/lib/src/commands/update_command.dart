import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class UpdateCommand extends DewCommand with DewToolCommand {
  UpdateCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        mandatory: true,
        help: 'Secret name.',
      )
      ..addOption('env', help: 'Use value from an environment variable.')
      ..addOption('file', help: 'Use value from file path.')
      ..addOption('metadata', help: 'JSON object to save as metadata.')
      ..addOption('metadata-file', help: 'Path to JSON metadata file.')
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'update';

  @override
  final String description = 'Update a secret value and/or metadata.';

  @override
  final String toolName = 'vault_update_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final secretName = requireStringArg(args, 'name');
    final mode = args['env'] != null || args['file'] != null ? 'value-update' : 'metadata-only';
    return renderVaultOutput(
      format: format,
      message: 'Update stub executed.',
      json: {
        'secret': secretName,
        'mode': mode,
      },
    );
  }

}
