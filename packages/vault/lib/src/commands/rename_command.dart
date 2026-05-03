import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class RenameCommand extends DewCommand with DewToolCommand {
  RenameCommand() {
    argParser
      ..addOption(
        'from',
        mandatory: true,
        help: 'Current secret name.',
      )
      ..addOption(
        'to',
        mandatory: true,
        help: 'New secret name.',
      )
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'rename';

  @override
  final String description = 'Rename a secret while preserving value and metadata.';

  @override
  final String toolName = 'vault_rename_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final from = requireStringArg(args, 'from');
    final to = requireStringArg(args, 'to');
    return renderVaultOutput(
      format: format,
      message: 'Rename stub executed.',
      json: {'from': from, 'to': to},
    );
  }

}
