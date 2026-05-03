import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class SetCommand extends DewCommand with DewToolCommand {
  SetCommand() {
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
  final String name = 'set';

  @override
  final String description = 'Set a secret value and optional metadata.';

  @override
  final String toolName = 'vault_set_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final secretName = requireStringArg(args, 'name');
    final source =
        args['env'] ?? args['file'] ?? args['metadata'] ?? args['metadata-file'];
    return renderVaultOutput(
      format: format,
      message: 'Set stub executed.',
      json: {
        'secret': secretName,
        'source': source == null ? 'interactive' : source.toString(),
        'status': 'set',
      },
    );
  }

}
