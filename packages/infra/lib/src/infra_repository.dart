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

  /// Finds all service manifests below `services/*/manifest.yaml`.
  Future<List<InfraServiceManifest>> list() async {
    final root = fs.directory(servicesDir);
    if (!await root.exists()) return const [];

    final manifests = <InfraServiceManifest>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifest = fs.file(p.join(entity.path, 'manifest.yaml'));
      if (!await manifest.exists()) continue;
      manifests.add(
        await loadFromManifestPath(manifest.path, serviceDir: entity.path),
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
    final manifestPath = p.join(servicesDir, id, 'manifest.yaml');
    final file = fs.file(manifestPath);
    if (!await file.exists()) return null;
    return loadFromManifestPath(
      manifestPath,
      serviceDir: p.dirname(manifestPath),
    );
  }

  /// Parses the manifest at [manifestPath].
  Future<InfraServiceManifest> loadFromManifestPath(
    String manifestPath, {
    required String serviceDir,
  }) async {
    final file = fs.file(manifestPath);
    return InfraServiceManifest.parse(
      contents: await file.readAsString(),
      serviceDir: p.normalize(serviceDir),
      manifestPath: p.normalize(manifestPath),
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
        manifest.manifestPath,
        'id "${manifest.id}" must match directory "$dirId".',
      );
    }

    if (manifest.quadlets.isEmpty) {
      issue(manifest.manifestPath, 'quadlets must contain at least one file.');
    }
    final quadletFiles = <String>{};
    final quadletUnits = <String>{};
    for (final quadlet in manifest.quadlets) {
      if (!quadletFiles.add(quadlet.file)) {
        issue(
          manifest.manifestPath,
          'quadlet file "${quadlet.file}" is declared more than once.',
        );
      }
      if (!quadletUnits.add(quadlet.serviceUnit)) {
        issue(
          manifest.manifestPath,
          'quadlet unit "${quadlet.serviceUnit}" is declared more than once.',
        );
      }
      if (!quadlet.serviceUnit.endsWith('.service')) {
        issue(
          manifest.manifestPath,
          'quadlet unit "${quadlet.serviceUnit}" must end with .service.',
        );
      }
      await _requireFile(manifest, quadlet.filePath, issues);
      await _requireDirectoryIfDeclared(
        manifest,
        quadlet.dropinsDirPath,
        issues,
      );
      await _requireDirectoryIfDeclared(
        manifest,
        quadlet.profilesDirPath,
        issues,
      );
    }
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
          path: manifest.manifestPath,
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
