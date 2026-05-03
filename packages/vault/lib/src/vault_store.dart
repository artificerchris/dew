import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'vault_crypto.dart';

class VaultSecretRecord {
  final String name;
  final String value;
  final Map<String, dynamic> metadata;

  const VaultSecretRecord({
    required this.name,
    required this.value,
    required this.metadata,
  });
}

class VaultStore {
  static final _namePattern = RegExp(r'^[A-Za-z0-9._-]+$');
  static const _secretSuffix = '.vault';
  static const _metadataSuffix = '.meta.json';

  final String storageDir;
  final String passwordFilePath;
  final FileSystem fs;
  final int iterations;

  const VaultStore({
    required this.storageDir,
    required this.passwordFilePath,
    this.fs = const LocalFileSystem(),
    this.iterations = VaultCrypto.defaultIterations,
  });

  Future<void> initialize() async {
    await fs.directory(storageDir).create(recursive: true);
    await fs.directory(p.dirname(passwordFilePath)).create(recursive: true);
    await ensurePassword();
  }

  Future<bool> exists(String name) async {
    _validateName(name);
    return fs.file(_secretPath(name)).exists();
  }

  Future<VaultSecretRecord?> read(String name) async {
    _validateName(name);
    final secretFile = fs.file(_secretPath(name));
    if (!await secretFile.exists()) return null;

    final payloadText = await secretFile.readAsString();
    final payload = jsonDecode(payloadText);
    if (payload is! Map) {
      throw ArgumentError('Secret "$name" is malformed.');
    }

    final password = await readPassword();
    final value = VaultCrypto.decryptFromEnvelope(
      Map<String, dynamic>.from(payload),
      password: password,
    );

    final metadata = await _readMetadata(name);
    return VaultSecretRecord(name: name, value: value, metadata: metadata);
  }

  Future<void> write(
    String name,
    String value, {
    Map<String, dynamic>? metadata,
  }) async {
    _validateName(name);
    if (value.trim().isEmpty) {
      throw ArgumentError('Secret value must not be empty.');
    }

    await initialize();
    final password = await readPassword();
    final envelope = VaultCrypto.encryptToEnvelope(
      value,
      password: password,
      iterations: iterations,
    );
    await fs.file(_secretPath(name)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
    );

    await _writeMetadata(name, metadata);
  }

  Future<void> delete(String name) async {
    _validateName(name);
    final secretFile = fs.file(_secretPath(name));
    if (!await secretFile.exists()) {
      throw ArgumentError('Secret "$name" not found.');
    }
    await secretFile.delete();
    final metadataFile = fs.file(_metadataPath(name));
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
  }

  Future<void> rename(String from, String to) async {
    _validateName(from);
    _validateName(to);
    if (from == to) return;

    final fromSecret = fs.file(_secretPath(from));
    if (!await fromSecret.exists()) {
      throw ArgumentError('Secret "$from" not found.');
    }
    final toSecret = fs.file(_secretPath(to));
    if (await toSecret.exists()) {
      throw ArgumentError('Secret "$to" already exists.');
    }

    final toMetadata = fs.file(_metadataPath(to));
    final fromMetadata = fs.file(_metadataPath(from));

    await fromSecret.rename(toSecret.path);
    if (await fromMetadata.exists()) {
      if (await toMetadata.exists()) {
        throw ArgumentError('Metadata for "$to" already exists.');
      }
      await fromMetadata.rename(toMetadata.path);
    }
  }

  Future<int> rotateVaultPassword() async {
    final names = await listSecretNames();
    if (names.isEmpty) {
      return 0;
    }

    final password = await readPassword();
    final records = <VaultSecretRecord>[];
    for (final name in names) {
      final payload = await _readWithPassword(name, password: password);
      if (payload == null) {
        throw ArgumentError('Failed to read secret "$name" for rotation.');
      }
      records.add(payload);
    }

    final newPassword = VaultCrypto.randomPassword(length: 64);
    for (final record in records) {
      await _writeWithPassword(
        record.name,
        value: record.value,
        password: newPassword,
        metadata: record.metadata,
      );
    }
    await writePassword(newPassword);
    return records.length;
  }

  Future<List<String>> listSecretNames() async {
    final dir = fs.directory(storageDir);
    if (!await dir.exists()) return const [];

    final names = <String>[];
    await for (final file in dir.list()) {
      if (file is! File) continue;
      if (p.extension(file.path) != _secretSuffix) continue;
      final name = p.basenameWithoutExtension(file.path);
      if (name.isNotEmpty) names.add(name);
    }
    names.sort();
    return names;
  }

  Future<String> ensurePassword() async {
    final file = fs.file(passwordFilePath);
    if (!await file.exists()) {
      final password = VaultCrypto.randomPassword(length: 64);
      await writePassword(password);
      return password;
    }
    final existing = await file.readAsString();
    if (existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final password = VaultCrypto.randomPassword(length: 64);
    await writePassword(password);
    return password;
  }

  Future<String> readPassword() async {
    final file = fs.file(passwordFilePath);
    if (!await file.exists()) {
      throw ArgumentError('Vault password file not found at $passwordFilePath.');
    }
    final password = (await file.readAsString()).trim();
    if (password.isEmpty) {
      throw ArgumentError('Vault password file is empty at $passwordFilePath.');
    }
    return password;
  }

  Future<void> writePassword(String password) async {
    await fs.directory(p.dirname(passwordFilePath)).create(recursive: true);
    await fs.file(passwordFilePath).writeAsString(password);
  }

  Future<Map<String, dynamic>> readMetadata(String name) async {
    _validateName(name);
    return _readMetadata(name);
  }

  Future<void> writeMetadata(String name, Map<String, dynamic> metadata) async {
    _validateName(name);
    await initialize();
    await _writeMetadata(name, metadata);
  }

  Future<void> _writeMetadata(String name, Map<String, dynamic>? metadata) async {
    final metadataPath = _metadataPath(name);
    final file = fs.file(metadataPath);
    if (metadata == null || metadata.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final normalized = metadata.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized),
    );
  }

  Future<Map<String, dynamic>> _readMetadata(String name) async {
    final metadataFile = fs.file(_metadataPath(name));
    if (!await metadataFile.exists()) return {};
    final raw = await metadataFile.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ArgumentError('Metadata for "$name" is malformed.');
    }
    return Map<String, dynamic>.from(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<VaultSecretRecord?> _readWithPassword(
    String name, {
    required String password,
  }) async {
    final secretFile = fs.file(_secretPath(name));
    if (!await secretFile.exists()) return null;

    final payloadText = await secretFile.readAsString();
    final payload = jsonDecode(payloadText);
    if (payload is! Map) {
      throw ArgumentError('Secret "$name" is malformed.');
    }
    final value = VaultCrypto.decryptFromEnvelope(
      Map<String, dynamic>.from(payload),
      password: password,
    );
    final metadata = await _readMetadata(name);
    return VaultSecretRecord(name: name, value: value, metadata: metadata);
  }

  Future<void> _writeWithPassword(
    String name, {
    required String value,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    final envelope = VaultCrypto.encryptToEnvelope(
      value,
      password: password,
      iterations: iterations,
    );
    await fs.file(_secretPath(name)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
    );
    await _writeMetadata(name, metadata);
  }

  String _secretPath(String name) => p.join(storageDir, '$name$_secretSuffix');
  String _metadataPath(String name) => p.join(storageDir, '$name$_metadataSuffix');

  void _validateName(String name) {
    if (!_namePattern.hasMatch(name)) {
      throw ArgumentError(
        'Invalid secret name "$name". '
        'Use only letters, numbers, underscore, dash, and dot.',
      );
    }
  }
}
