import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class VaultInitCommand extends DewCommand with DewToolCommand {
  VaultInitCommand() {
    argParser
      ..addOption(
        'password-file',
        abbr: 'p',
        defaultsTo: '.project/secrets/dew.vault.password',
        help: 'Path to the vault password file to record in config.',
      )
      ..addOption(
        'storage-dir',
        defaultsTo: '.project/vault',
        help: 'Directory where encrypted secret files are stored.',
      )
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'init';

  @override
  final String description = 'Initialise vault directories and defaults.';

  @override
  final String toolName = 'vault_init';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final passwordFile = requireStringArg(args, 'password-file');
    final storageDir = requireStringArg(args, 'storage-dir');
    return renderVaultOutput(
      format: format,
      message: 'Vault init stub completed.',
      json: {
        'password_file': passwordFile,
        'storage_dir': storageDir,
        'initialized': true,
      },
    );
  }
}
