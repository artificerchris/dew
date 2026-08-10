import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../command_output.dart';
import '../vault_config.dart';
import '../vault_store.dart';

class RenameCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  RenameCommand({this._fs = const LocalFileSystem()}) {
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
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: context.resolveConfigPath(config.storageDir),
      passwordFilePath: context.resolveConfigPath(config.passwordFile),
      fs: context.fs,
    );
    await store.rename(from, to);

    return renderVaultOutput(
      format: format,
      message: 'Renamed.',
      json: {'from': from, 'to': to},
    );
  }

}
