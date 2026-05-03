import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

class VaultGeneratorDefinition {
  final String type;
  final String? description;
  final Map<String, dynamic> config;

  const VaultGeneratorDefinition({
    required this.type,
    this.description,
    required this.config,
  });
}

class VaultConfig {
  final String passwordFile;
  final String storageDir;
  final Map<String, VaultGeneratorDefinition> generators;

  const VaultConfig({
    required this.passwordFile,
    required this.storageDir,
    required this.generators,
  });
}

extension VaultDewConfig on DewConfig {
  static const _defaultPasswordFile = '.project/secrets/dew.vault.password';
  static const _defaultStorageDir = '.project/vault';

  VaultConfig get vault {
    final dewSection = _coerceMap(_asMap(raw['dew']));
    final vaultSection = _coerceMap(dewSection['vault']);

    final storageDir = _asString(
      vaultSection['storage_dir'],
      fallback: _defaultStorageDir,
    );
    final passwordFile = _asString(
      vaultSection['password_file'],
      fallback: _defaultPasswordFile,
    );

    final generators = <String, VaultGeneratorDefinition>{};
    final generatorSection = vaultSection['generators'];
    if (generatorSection is Map) {
      for (final entry in generatorSection.entries) {
        if (entry.key == null) continue;
        final name = entry.key.toString();
        final definition = _coerceMap(entry.value);
        final type = _asString(definition['type'], fallback: '');
        if (type.isEmpty) continue;
        generators[name] = VaultGeneratorDefinition(
          type: type,
          description: _asString(definition['description'], fallback: null),
          config: _coerceMap(definition['config']),
        );
      }
    }

    return VaultConfig(
      passwordFile: passwordFile,
      storageDir: storageDir,
      generators: generators,
    );
  }
}

extension VaultDirs on ProjectDirs {
  String get vaultStorage => p.join(project, 'vault');
  String get vaultSecrets => p.join(project, 'secrets');
}

String _asString(dynamic value, {String? fallback}) {
  if (value == null) return fallback ?? '';
  return value.toString();
}

Map<String, dynamic> _coerceMap(dynamic input) {
  if (input == null) return {};
  if (input is Map) {
    return input.map((key, value) => MapEntry(key.toString(), _coerceValue(value)));
  }
  return {};
}

Map<String, dynamic> _coerceMapOfDynamic(dynamic input) {
  return _coerceMap(input);
}

dynamic _coerceValue(dynamic value) {
  if (value is Map) return _coerceMap(value);
  if (value is List) return value.map(_coerceValue).toList();
  return value;
}

Map<String, dynamic> _asMap(dynamic value) => _coerceMapOfDynamic(value);

