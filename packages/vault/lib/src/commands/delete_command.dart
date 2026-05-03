import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../vault_config.dart';
import '../vault_store.dart';
import '../command_output.dart';

class DeleteCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  DeleteCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
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
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: resolveProjectPath(context.root, config.storageDir),
      passwordFilePath: resolveProjectPath(context.root, config.passwordFile),
      fs: context.fs,
    );
    await store.delete(secretName);

    return renderVaultOutput(
      format: format,
      message: 'Deleted.',
      json: {'secret': secretName},
    );
  }

}
