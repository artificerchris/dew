import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../vault_store.dart';
import '../command_output.dart';

class VaultInitCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  VaultInitCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
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
    final passwordFile = args['password-file']?.toString() ?? '.project/secrets/dew.vault.password';
    final storageDir = args['storage-dir']?.toString() ?? '.project/vault';

    final context = await ProjectContext.find(fs: _fs);
    final store = VaultStore(
      storageDir: context.resolveConfigPath(storageDir),
      passwordFilePath: context.resolveConfigPath(passwordFile),
      fs: context.fs,
    );
    await store.initialize();

    return renderVaultOutput(
      format: format,
      message: 'Vault initialised.',
      json: {
        'password_file': store.passwordFilePath,
        'storage_dir': store.storageDir,
        'initialized': true,
      },
    );
  }
}
