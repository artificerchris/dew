import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../command_output.dart';
import '../vault_config.dart';
import '../vault_store.dart';

class GetCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  GetCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption('name', abbr: 'n', mandatory: true, help: 'Secret name.')
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'get';

  @override
  final String description = 'Get a secret value.';

  @override
  final String toolName = 'vault_get_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final secretName = requireStringArg(args, 'name');

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: context.resolveConfigPath(config.storageDir),
      passwordFilePath: context.resolveConfigPath(config.passwordFile),
      fs: context.fs,
    );

    final record = await store.read(secretName);
    if (record == null) {
      throw ArgumentError('Secret "$secretName" not found.');
    }

    return renderVaultOutput(
      format: format,
      message: record.value,
      json: {
        'name': record.name,
        'value': record.value,
        'metadata': record.metadata,
      },
    );
  }
}
