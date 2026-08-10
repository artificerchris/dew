import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../command_output.dart';
import '../vault_config.dart';
import '../vault_generators.dart';
import '../vault_store.dart';

class RotateCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  RotateCommand({this._fs = const LocalFileSystem()}) {
    argParser
      ..addOption('name', help: 'Secret name to rotate; omit to rotate vault password.')
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'rotate';

  @override
  final String description =
      'Rotate vault password or a single secret value.';

  @override
  final String toolName = 'vault_rotate_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final target = args['name']?.toString();
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.vault;
    final store = VaultStore(
      storageDir: context.resolveConfigPath(config.storageDir),
      passwordFilePath: context.resolveConfigPath(config.passwordFile),
      fs: context.fs,
    );

    if (target == null || target.trim().isEmpty) {
      final rotatedCount = await store.rotateVaultPassword();
      return renderVaultOutput(
        format: format,
        message: 'Vault password rotated.',
        json: {
          'scope': 'vault',
          'rotated_count': rotatedCount,
        },
      );
    }

    final record = await store.read(target);
    if (record == null) throw ArgumentError('Secret "$target" not found.');
    final value = _rotateValue(config, record);
    await store.write(target, value, metadata: record.metadata);

    return renderVaultOutput(
      format: format,
      message: 'Secret rotated.',
      json: {
        'scope': 'secret',
        'name': target,
      },
    );
  }

  String _rotateValue(
    VaultConfig vaultConfig,
    VaultSecretRecord record,
  ) {
    final rotationConfig = record.metadata['rotation'];
    if (rotationConfig is Map) {
      final configEntries = Map<String, dynamic>.fromEntries(
        rotationConfig.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );
      final generatorName = configEntries.remove('generator')?.toString();
      configEntries.remove('enabled');

      if (generatorName != null && generatorName.isNotEmpty) {
        if (vaultConfig.generators.containsKey(generatorName) ||
            [
                  'random_password',
                  'random_token',
                  'uuid_v4',
                ].contains(generatorName)) {
          return VaultGenerators.generateByName(
            nameOrType: generatorName,
            generators: vaultConfig.generators,
            options: configEntries,
          );
        }
        throw ArgumentError('Unknown rotation generator "$generatorName".');
      }

      if (configEntries.isNotEmpty) {
        return VaultGenerators.generate('random_password', configEntries);
      }
    }

    return VaultGenerators.generate('random_password', {});
  }
}
