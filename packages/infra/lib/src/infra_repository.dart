import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

import 'service_manifest.dart';

/// Reads infrastructure manifests from `.project/infrastructure`.
class InfraRepository {
  const InfraRepository({
    required this.infraDir,
    this.fs = const LocalFileSystem(),
  });

  /// Absolute path to the infrastructure root.
  final String infraDir;

  /// File system abstraction for tests and non-local callers.
  final FileSystem fs;

  /// Absolute path to the service directory root.
  String get servicesDir => p.join(infraDir, 'services');

  /// Finds all service manifests below `services/*/metadata.toml`.
  Future<List<InfraServiceManifest>> list() async {
    final root = fs.directory(servicesDir);
    if (!await root.exists()) return const [];

    final manifests = <InfraServiceManifest>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final metadata = fs.file(p.join(entity.path, 'metadata.toml'));
      if (!await metadata.exists()) continue;
      manifests.add(
        await loadFromMetadataPath(metadata.path, serviceDir: entity.path),
      );
    }
    manifests.sort((a, b) => a.id.compareTo(b.id));
    return manifests;
  }

  /// Loads a single service by command-line [id].
  Future<InfraServiceManifest> get(String id) async {
    final manifest = await find(id);
    if (manifest == null) {
      throw ArgumentError('Infrastructure service "$id" not found.');
    }
    return manifest;
  }

  /// Loads a single service by command-line [id], returning null if absent.
  Future<InfraServiceManifest?> find(String id) async {
    final metadataPath = p.join(servicesDir, id, 'metadata.toml');
    final file = fs.file(metadataPath);
    if (!await file.exists()) return null;
    return loadFromMetadataPath(
      metadataPath,
      serviceDir: p.dirname(metadataPath),
    );
  }

  /// Parses the manifest at [metadataPath].
  Future<InfraServiceManifest> loadFromMetadataPath(
    String metadataPath, {
    required String serviceDir,
  }) async {
    final file = fs.file(metadataPath);
    return InfraServiceManifest.parse(
      contents: await file.readAsString(),
      serviceDir: p.normalize(serviceDir),
      metadataPath: p.normalize(metadataPath),
    );
  }
}

/// A validation issue found in an infrastructure manifest or referenced file.
class InfraValidationIssue {
  const InfraValidationIssue({
    required this.serviceId,
    required this.path,
    required this.message,
  });

  /// Service id, or the best available directory name when parsing failed.
  final String serviceId;

  /// Path where the issue was discovered.
  final String path;

  /// Human-readable issue.
  final String message;

  /// Machine-readable issue.
  Map<String, String> toJson() => {
    'service': serviceId,
    'path': path,
    'message': message,
  };

  @override
  String toString() => '$serviceId: $message ($path)';
}

/// Validates service manifests and their referenced files.
class InfraValidator {
  const InfraValidator({this.fs = const LocalFileSystem()});

  /// File system abstraction for tests and non-local callers.
  final FileSystem fs;

  /// Validates [manifest].
  Future<List<InfraValidationIssue>> validate(
    InfraServiceManifest manifest,
  ) async {
    final issues = <InfraValidationIssue>[];
    void issue(String path, String message) => issues.add(
      InfraValidationIssue(
        serviceId: manifest.id,
        path: path,
        message: message,
      ),
    );

    final dirId = p.basename(manifest.serviceDir);
    if (manifest.id != dirId) {
      issue(
        manifest.metadataPath,
        'service.id "${manifest.id}" must match directory "$dirId".',
      );
    }
    if (!manifest.unit.endsWith('.service')) {
      issue(manifest.metadataPath, 'service.unit must end with .service.');
    }
    if (manifest.unit != manifest.expectedUnit) {
      issue(
        manifest.metadataPath,
        'service.unit "${manifest.unit}" must match container file unit '
        '"${manifest.expectedUnit}".',
      );
    }

    await _requireFile(manifest, manifest.containerFilePath, issues);
    await _requireDirectoryIfDeclared(
      manifest,
      manifest.dropinsDirPath,
      issues,
    );
    await _requireDirectoryIfDeclared(
      manifest,
      manifest.profilesDirPath,
      issues,
    );
    await _validateJsonSchema(
      manifest,
      label: 'configure schema',
      path: manifest.configureSchemaPath,
      issues: issues,
    );
    await _validateJsonSchema(
      manifest,
      label: 'init schema',
      path: manifest.initSchemaPath,
      issues: issues,
    );

    return issues;
  }

  Future<void> _requireFile(
    InfraServiceManifest manifest,
    String path,
    List<InfraValidationIssue> issues,
  ) async {
    if (!await fs.file(path).exists()) {
      issues.add(
        InfraValidationIssue(
          serviceId: manifest.id,
          path: path,
          message: 'Referenced file does not exist.',
        ),
      );
    }
  }

  Future<void> _requireDirectoryIfDeclared(
    InfraServiceManifest manifest,
    String? path,
    List<InfraValidationIssue> issues,
  ) async {
    if (path == null) return;
    if (!await fs.directory(path).exists()) {
      issues.add(
        InfraValidationIssue(
          serviceId: manifest.id,
          path: path,
          message: 'Referenced directory does not exist.',
        ),
      );
    }
  }

  Future<void> _validateJsonSchema(
    InfraServiceManifest manifest, {
    required String label,
    required String? path,
    required List<InfraValidationIssue> issues,
  }) async {
    if (path == null) {
      issues.add(
        InfraValidationIssue(
          serviceId: manifest.id,
          path: manifest.metadataPath,
          message: 'Missing $label path.',
        ),
      );
      return;
    }
    final file = fs.file(path);
    if (!await file.exists()) {
      issues.add(
        InfraValidationIssue(
          serviceId: manifest.id,
          path: path,
          message: 'Referenced $label does not exist.',
        ),
      );
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      JsonSchema.create(decoded);
    } catch (error) {
      issues.add(
        InfraValidationIssue(
          serviceId: manifest.id,
          path: path,
          message: 'Invalid $label: $error',
        ),
      );
    }
  }
}
