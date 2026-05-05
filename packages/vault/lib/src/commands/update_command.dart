import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../vault_config.dart';
import '../vault_store.dart';
import '../command_output.dart';

class UpdateCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  UpdateCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
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
    final hasValueSource = args['env'] != null || args['file'] != null;
    final hasMetadataSource =
        args['metadata'] != null || args['metadata-file'] != null;

    if (!hasValueSource && !hasMetadataSource) {
      throw ArgumentError(
        'No update provided. Use --env or --file and/or --metadata / --metadata-file.',
      );
    }

    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: context.resolveConfigPath(config.storageDir),
      passwordFilePath: context.resolveConfigPath(config.passwordFile),
      fs: context.fs,
    );

    final existing = await store.read(secretName);
    if (existing == null) throw ArgumentError('Secret "$secretName" not found.');

    Map<String, dynamic> updatedMetadata;
    if (hasMetadataSource) {
      final provided = await parseMetadataFromArgs(
        args: args,
        fs: context.fs,
        projectRoot: context.root,
      );
      updatedMetadata = provided.isEmpty ? {} : mergeMetadata(existing.metadata, provided);
    } else {
      updatedMetadata = existing.metadata;
    }

    String? value;
    if (hasValueSource) {
      value = await readSecretInput(
        args,
        fs: context.fs,
        projectRoot: context.root,
        required: true,
        allowStdin: false,
      );
    }

    final finalValue = value ?? existing.value;
    await store.write(secretName, finalValue, metadata: updatedMetadata);

    return renderVaultOutput(
      format: format,
      message: 'Secret updated.',
      json: {
        'name': secretName,
        'updated_metadata': hasMetadataSource,
        'updated_value': hasValueSource,
      },
    );
  }

}
