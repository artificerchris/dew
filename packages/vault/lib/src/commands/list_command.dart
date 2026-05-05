import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../vault_config.dart';
import '../vault_store.dart';
import '../command_output.dart';

class ListCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  ListCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
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
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: context.resolveConfigPath(config.storageDir),
      passwordFilePath: context.resolveConfigPath(config.passwordFile),
      fs: context.fs,
    );
    final names = await store.listSecretNames();
    if (names.isEmpty) {
      return renderVaultOutput(
        format: format,
        message: 'No secrets found.',
        json: {'secrets': const <String>[], 'count': 0},
      );
    }

    final output = names.join('\n');
    return renderVaultOutput(
      format: format,
      message: output,
      json: {
        'secrets': names,
        'count': names.length,
      },
    );
  }

}
