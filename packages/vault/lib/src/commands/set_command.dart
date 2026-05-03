import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../command_output.dart';
import '../vault_config.dart';
import '../vault_store.dart';

class SetCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  SetCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
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

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: resolveProjectPath(context.root, config.storageDir),
      passwordFilePath: resolveProjectPath(context.root, config.passwordFile),
      fs: context.fs,
    );

    final metadata = await parseMetadataFromArgs(
      args: args,
      fs: context.fs,
      projectRoot: context.root,
    );
    final value = await readSecretInput(
      args,
      fs: context.fs,
      projectRoot: context.root,
      required: true,
      allowStdin: false,
    );

    await store.write(secretName, value!, metadata: metadata);

    return renderVaultOutput(
      format: format,
      message: 'Stored secret.',
      json: {
        'name': secretName,
        'metadata': metadata,
      },
    );
  }
}
