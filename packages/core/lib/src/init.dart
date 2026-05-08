import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:liquify/liquify.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';

/// Options passed to every [DewInitHook] during `dew init`.
class DewInitOptions {
  /// Whether to create `.gitkeep` files in newly-created empty directories.
  final bool gitkeep;

  const DewInitOptions({this.gitkeep = true});
}

/// Creates the initial `.project/` scaffold for `dew init`.
///
/// Each module (kanban, mcp, etc.) registers a hook so it can create its own
/// subdirectories and config alongside the core scaffold.
abstract interface class DewInitHook {
  /// Called after `dew.yaml` is written. [projectRoot] is the resolved absolute
  /// path of the project being initialised; [config] is the loaded config;
  /// [options] carries flags like [DewInitOptions.gitkeep].
  Future<void> onInit(
    String projectRoot,
    DewConfig config,
    DewInitOptions options,
  );
}

const _defaultDewYaml = '''
dew:
  mcp:
    host: "localhost"
    port: 8080

  kanban:
    prefix: "PROJ"
    ticket_types:
      - id: "epic"
        name: "Epic"
      - id: "story"
        name: "Story"
      - id: "task"
        name: "Task"
      - id: "bug"
        name: "Bug"
      - id: "spike"
        name: "Spike"
    columns:
      - id: "backlog"
        name: "Backlog"
        color: "blue"
      - id: "doing"
        name: "Doing"
        color: "yellow"
      - id: "done"
        name: "Done"
        color: "green"
''';

const _projectGitignore = '''
/secrets/
/toolchain/
/cache/
''';

const _defaultScaffoldName = '_default';

class InitCommand extends Command<void> {
  final List<DewInitHook> _hooks;
  final FileSystem _fs;

  InitCommand(
    List<DewInitHook> hooks, {
    FileSystem fs = const LocalFileSystem(),
  }) : this._(hooks, fs);

  InitCommand._(this._hooks, this._fs) {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Path to the project root to initialise.',
        defaultsTo: '.',
      )
      ..addFlag(
        'gitkeep',
        help: 'Add .gitkeep files to newly-created empty directories.',
        defaultsTo: true,
      )
      ..addMultiOption(
        'scaffold',
        help:
            'Base scaffold to apply (name or path). Repeat to layer multiple '
            'base scaffolds in order.',
      )
      ..addMultiOption(
        'scaffold-merge',
        help:
            'Additional scaffold to merge in order (name or path). Colliding '
            'paths are replaced by later merge entries.',
      )
      ..addMultiOption(
        'scaffold-strict',
        help:
            'Additional scaffold to apply in strict mode (name or path). '
            'Colliding paths fail init.',
      );
  }

  @override
  final String name = 'init';

  @override
  final String description =
      'Initialise a Dew project at the given path, creating '
      '.project/dew.yaml, scaffolding module directories, and optional '
      'user-defined scaffolds.';

  @override
  Future<void> run() async {
    final rawPath = argResults!['path'] as String;
    final gitkeep = argResults!['gitkeep'] as bool;
    final baseScaffolds = _toStringList(argResults!['scaffold']);
    final mergeScaffolds = _toStringList(argResults!['scaffold-merge']);
    final strictScaffolds = _toStringList(argResults!['scaffold-strict']);
    final projectRoot = p.canonicalize(rawPath);
    final options = DewInitOptions(gitkeep: gitkeep);

    final projectDir = _fs.directory(p.join(projectRoot, '.project'));
    final configFile = _fs.file(p.join(projectDir.path, 'dew.yaml'));
    final gitignoreFile = _fs.file(p.join(projectDir.path, '.gitignore'));

    await projectDir.create(recursive: true);

    if (await configFile.exists()) {
      print('  found   .project/dew.yaml (already exists, skipping)');
    } else {
      await configFile.writeAsString(_defaultDewYaml.trimLeft());
      print('  created .project/dew.yaml');
    }

    if (await gitignoreFile.exists()) {
      print('  found   .project/.gitignore (already exists, skipping)');
    } else {
      await gitignoreFile.writeAsString(_projectGitignore);
      print('  created .project/.gitignore');
    }

    final config = DewConfig.fromYaml(
      loadYaml(await configFile.readAsString()) as YamlMap,
    );

    for (final hook in _hooks) {
      await hook.onInit(projectRoot, config, options);
    }

    await _applyScaffolds(
      projectRoot: projectRoot,
      baseInputs: baseScaffolds,
      mergeInputs: mergeScaffolds,
      strictInputs: strictScaffolds,
    );

    print('\nProject initialised at $projectRoot');
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  Future<void> _applyScaffolds({
    required String projectRoot,
    required List<String> baseInputs,
    required List<String> mergeInputs,
    required List<String> strictInputs,
  }) async {
    final scaffoldRoot = _scaffoldRoot();
    final planned = <String, _PlannedScaffoldFile>{};

    final baseSequence = baseInputs.isEmpty
        ? const [_defaultScaffoldName]
        : baseInputs;

    if (baseInputs.isEmpty) {
      final defaultDir = _fs.directory(
        p.join(scaffoldRoot, _defaultScaffoldName),
      );
      if (!await defaultDir.exists()) {
        await defaultDir.create(recursive: true);
        print(
          '  created scaffold root $_defaultScaffoldName at ${defaultDir.path}',
        );
      }
    }

    for (final input in baseSequence) {
      final resolved = await _resolveScaffold(input, scaffoldRoot, projectRoot);
      await _collectAndApplyScaffold(
        planned: planned,
        scaffold: resolved,
        projectRoot: projectRoot,
        mode: _ScaffoldMode.merge,
      );
    }

    for (final input in mergeInputs) {
      final resolved = await _resolveScaffold(input, scaffoldRoot, projectRoot);
      await _collectAndApplyScaffold(
        planned: planned,
        scaffold: resolved,
        projectRoot: projectRoot,
        mode: _ScaffoldMode.merge,
      );
    }

    for (final input in strictInputs) {
      final resolved = await _resolveScaffold(input, scaffoldRoot, projectRoot);
      await _collectAndApplyScaffold(
        planned: planned,
        scaffold: resolved,
        projectRoot: projectRoot,
        mode: _ScaffoldMode.strict,
      );
    }

    for (final entry in planned.entries) {
      final targetPath = p.join(projectRoot, entry.key);
      final targetFile = _fs.file(targetPath);
      if (await targetFile.exists() &&
          !_canMergeIntoExistingTarget(entry.key)) {
        throw StateError(
          'Scaffold collision at "${entry.key}" with existing project file. '
          'Choose a different scaffold set or remove the destination file.',
        );
      }
    }

    for (final entry in planned.entries) {
      final targetPath = p.join(projectRoot, entry.key);
      final targetDir = _fs.directory(p.dirname(targetPath));
      await targetDir.create(recursive: true);
      await _fs.file(targetPath).writeAsString(entry.value.content);
      print('  scaffold ${entry.key} <- ${entry.value.scaffoldLabel}');
    }
  }

  bool _canMergeIntoExistingTarget(String targetPath) {
    return targetPath == '.editorconfig';
  }

  String _scaffoldRoot() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return p.join(xdg, 'dew', 'scaffolds');
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return p.join('~', '.config', 'dew', 'scaffolds');
    }
    return p.join(home, '.config', 'dew', 'scaffolds');
  }

  Future<_ResolvedScaffold> _resolveScaffold(
    String input,
    String scaffoldRoot,
    String projectRoot,
  ) async {
    final explicitPath = _candidatePath(input, projectRoot);
    final explicitDir = _fs.directory(explicitPath);
    if (await explicitDir.exists()) {
      return _ResolvedScaffold(
        label: input,
        directoryPath: p.canonicalize(explicitDir.path),
      );
    }

    if (_looksPathLike(input)) {
      throw StateError('Scaffold path not found: "$input".');
    }

    final namedPath = p.join(scaffoldRoot, input);
    final namedDir = _fs.directory(namedPath);
    if (await namedDir.exists()) {
      return _ResolvedScaffold(
        label: input,
        directoryPath: p.canonicalize(namedDir.path),
      );
    }

    throw StateError(
      'Scaffold "$input" not found. Looked for a local path first, then '
      '"$namedPath".',
    );
  }

  String _candidatePath(String input, String projectRoot) {
    if (input.startsWith('~')) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        if (input == '~') return home;
        if (input.startsWith('~/')) return p.join(home, input.substring(2));
      }
    }
    if (p.isAbsolute(input)) return p.normalize(input);
    return p.normalize(p.join(projectRoot, input));
  }

  bool _looksPathLike(String input) {
    return input.startsWith('/') ||
        input.startsWith('./') ||
        input.startsWith('../') ||
        input.startsWith('~/') ||
        input.contains('/') ||
        input.contains(r'\');
  }

  Future<void> _collectAndApplyScaffold({
    required Map<String, _PlannedScaffoldFile> planned,
    required _ResolvedScaffold scaffold,
    required String projectRoot,
    required _ScaffoldMode mode,
  }) async {
    final contributions = await _discoverScaffoldFiles(scaffold);
    if (contributions.isEmpty) {
      print('  found   scaffold "${scaffold.label}" (no files)');
      return;
    }

    for (final entry in contributions.entries) {
      final targetPath = entry.key;
      if (targetPath == '.project/.gitignore') {
        // Core init already owns this file; scaffold copies should not shadow it.
        continue;
      }

      final contribution = entry.value;
      final prior = planned[targetPath];

      if (prior != null && mode == _ScaffoldMode.strict) {
        throw StateError(
          'Strict scaffold collision at "$targetPath" between '
          '"${prior.scaffoldLabel}" and "${scaffold.label}".',
        );
      }

      var baseContent = prior?.content ?? '';
      if (prior == null && _canMergeIntoExistingTarget(targetPath)) {
        final existing = _fs.file(p.join(projectRoot, targetPath));
        if (await existing.exists()) {
          baseContent = await existing.readAsString();
        }
      }
      if (contribution.templateSourcePath != null) {
        final renderedTemplate = await _renderLiquidFile(
          sourcePath: contribution.templateSourcePath!,
          projectRoot: projectRoot,
          scaffoldLabel: scaffold.label,
          targetPath: targetPath,
        );
        if (_canMergeIntoExistingTarget(targetPath)) {
          baseContent = _mergeEditorConfig(baseContent, renderedTemplate);
        } else {
          baseContent = renderedTemplate;
        }
      } else if (contribution.staticSourcePath != null) {
        final staticContent = await _fs
            .file(contribution.staticSourcePath!)
            .readAsString();
        if (_canMergeIntoExistingTarget(targetPath)) {
          baseContent = _mergeEditorConfig(baseContent, staticContent);
        } else {
          baseContent = staticContent;
        }
      }

      for (final partSourcePath in contribution.partSourcePaths) {
        final renderedPart = await _renderLiquidFile(
          sourcePath: partSourcePath,
          projectRoot: projectRoot,
          scaffoldLabel: scaffold.label,
          targetPath: targetPath,
        );
        final parsedPart = _parsePartContent(renderedPart);
        final regionName = _partRegionName(
          parsedPart,
          p.basename(partSourcePath),
        );
        baseContent = _removeRegionBlock(
          content: baseContent,
          targetPath: targetPath,
          regionName: regionName,
        );
        final part = _wrapPartWithRegion(
          targetPath: targetPath,
          part: parsedPart,
          fallbackRegionName: regionName,
        );
        if (_canMergeIntoExistingTarget(targetPath)) {
          baseContent = _mergeEditorConfig(baseContent, part);
        } else {
          baseContent = _appendTextPart(baseContent, part);
        }
      }

      planned[targetPath] = _PlannedScaffoldFile(
        scaffoldLabel: scaffold.label,
        content: baseContent,
      );
    }
  }

  Future<Map<String, _ScaffoldContribution>> _discoverScaffoldFiles(
    _ResolvedScaffold scaffold,
  ) async {
    final root = _fs.directory(scaffold.directoryPath);
    final files = await root
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    final contributions = <String, _ScaffoldContribution>{};
    for (final file in files) {
      final relativePath = p.normalize(
        p.relative(file.path, from: scaffold.directoryPath),
      );
      if (relativePath.endsWith('.part.liquid')) {
        final target = relativePath.substring(
          0,
          relativePath.length - '.part.liquid'.length,
        );
        final current = contributions[target] ?? const _ScaffoldContribution();
        contributions[target] = current.copyWith(
          partSourcePaths: [...current.partSourcePaths, file.path],
        );
        continue;
      }
      if (relativePath.endsWith('.liquid')) {
        final target = relativePath.substring(
          0,
          relativePath.length - '.liquid'.length,
        );
        final current = contributions[target] ?? const _ScaffoldContribution();
        contributions[target] = current.copyWith(templateSourcePath: file.path);
        continue;
      }
      final current = contributions[relativePath] ?? const _ScaffoldContribution();
      contributions[relativePath] = current.copyWith(staticSourcePath: file.path);
    }
    return contributions;
  }

  Future<String> _renderLiquidFile({
    required String sourcePath,
    required String projectRoot,
    required String scaffoldLabel,
    required String targetPath,
  }) async {
    final source = await _fs.file(sourcePath).readAsString();
    final liquid = Liquid();
    return liquid.renderString(source, {
      'project_root': projectRoot,
      'scaffold': scaffoldLabel,
      'target': targetPath,
    });
  }

  String _appendTextPart(String base, String part) {
    if (part.trim().isEmpty) return base;
    if (base.isEmpty) return part;
    final separator = base.endsWith('\n') ? '' : '\n';
    return '$base$separator$part';
  }

  _ParsedPart _parsePartContent(String content) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final metadata = <String>[];
    var index = 0;
    while (index < lines.length) {
      final trimmed = lines[index].trim();
      if (trimmed.isEmpty) {
        index++;
        continue;
      }
      if (trimmed.startsWith('#') &&
          trimmed.contains(':') &&
          !trimmed.startsWith('#region') &&
          !trimmed.startsWith('#endregion')) {
        metadata.add(trimmed.substring(1).trim());
        index++;
        continue;
      }
      break;
    }
    final body = lines.skip(index).join('\n').trim();
    return _ParsedPart(metadata: metadata, body: body);
  }

  String _wrapPartWithRegion({
    required String targetPath,
    required _ParsedPart part,
    required String fallbackRegionName,
  }) {
    final commentPrefix = _commentPrefixForPath(targetPath);
    final regionName = _partRegionName(part, fallbackRegionName);
    final startRegion = _regionStart(commentPrefix, regionName);
    final endRegion = _regionEnd(commentPrefix, regionName);
    final buffer = StringBuffer();
    buffer.writeln(startRegion);
    for (final meta in part.metadata) {
      buffer.writeln('$commentPrefix $meta');
    }
    if (part.body.isNotEmpty) {
      if (part.metadata.isNotEmpty) buffer.writeln();
      buffer.writeln(part.body);
    }
    buffer.writeln(endRegion);
    return buffer.toString().trimRight();
  }

  String _commentPrefixForPath(String targetPath) {
    if (targetPath.endsWith('.editorconfig')) return '#';
    return '#';
  }

  String _regionStart(String commentPrefix, String regionName) {
    if (commentPrefix == '#') return '#region $regionName';
    return '$commentPrefix #region $regionName';
  }

  String _regionEnd(String commentPrefix, String regionName) {
    if (commentPrefix == '#') return '#endregion $regionName';
    return '$commentPrefix #endregion $regionName';
  }

  String _partRegionName(_ParsedPart part, String fallback) {
    for (final meta in part.metadata) {
      if (meta.startsWith('id:')) {
        final value = meta.substring('id:'.length).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return fallback;
  }

  String _removeRegionBlock({
    required String content,
    required String targetPath,
    required String regionName,
  }) {
    if (content.isEmpty) return content;
    final commentPrefix = _commentPrefixForPath(targetPath);
    final start = _regionStart(commentPrefix, regionName);
    final end = _regionEnd(commentPrefix, regionName);
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final kept = <String>[];
    var skipping = false;
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (!skipping && trimmed == start) {
        skipping = true;
        continue;
      }
      if (skipping) {
        if (trimmed == end) {
          skipping = false;
        }
        continue;
      }
      kept.add(line);
    }
    return kept.join('\n').trimRight();
  }

  String _mergeEditorConfig(String base, String part) {
    final baseSections = _parseEditorConfigSections(base);
    final partSections = _parseEditorConfigSections(part);

    for (final section in partSections.order) {
      final incoming = partSections.linesBySection[section] ?? const <String>[];
      final existing = baseSections.linesBySection[section] ?? const <String>[];
      if (!baseSections.linesBySection.containsKey(section)) {
        baseSections.order.add(section);
      }
      baseSections.linesBySection[section] = _mergeEditorConfigSection(
        existing: existing,
        incoming: incoming,
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < baseSections.order.length; i++) {
      final section = baseSections.order[i];
      final lines = baseSections.linesBySection[section] ?? const <String>[];
      if (section.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(section);
      } else if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      for (final line in lines) {
        buffer.writeln(line);
      }
    }
    var rendered = buffer.toString();
    rendered = rendered.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return '${rendered.trimRight()}\n';
  }

  List<String> _mergeEditorConfigSection({
    required List<String> existing,
    required List<String> incoming,
  }) {
    final merged = <String>[...existing];
    final keyIndex = <String, int>{};

    for (var i = 0; i < merged.length; i++) {
      final key = _editorConfigKey(merged[i]);
      if (key != null) {
        keyIndex[key] = i;
      }
    }

    for (final line in incoming) {
      final key = _editorConfigKey(line);
      if (key == null) {
        if (!merged.contains(line)) {
          merged.add(line);
        }
        continue;
      }
      final index = keyIndex[key];
      if (index == null) {
        keyIndex[key] = merged.length;
        merged.add(line);
      } else {
        merged[index] = line;
      }
    }

    return merged;
  }

  String? _editorConfigKey(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('#') || trimmed.startsWith(';')) return null;
    final match = RegExp(r'^([A-Za-z0-9_.-]+)\s*=').firstMatch(trimmed);
    if (match == null) return null;
    return match.group(1);
  }

  _EditorConfigSections _parseEditorConfigSections(String content) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final order = <String>[];
    final linesBySection = <String, List<String>>{};
    var currentSection = '';
    order.add(currentSection);
    linesBySection[currentSection] = <String>[];

    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        if (linesBySection[currentSection]!.isEmpty ||
            linesBySection[currentSection]!.last.isNotEmpty) {
          linesBySection[currentSection]!.add('');
        }
        continue;
      }
      final isHeader = trimmed.startsWith('[') && trimmed.endsWith(']');
      if (isHeader) {
        currentSection = trimmed;
        if (!linesBySection.containsKey(currentSection)) {
          order.add(currentSection);
          linesBySection[currentSection] = <String>[];
        }
        continue;
      }
      linesBySection[currentSection]!.add(raw);
    }

    for (final key in linesBySection.keys.toList()) {
      final sectionLines = linesBySection[key]!;
      while (sectionLines.isNotEmpty && sectionLines.last.isEmpty) {
        sectionLines.removeLast();
      }
    }

    return _EditorConfigSections(order: order, linesBySection: linesBySection);
  }
}

enum _ScaffoldMode { merge, strict }

class _ResolvedScaffold {
  final String label;
  final String directoryPath;

  const _ResolvedScaffold({
    required this.label,
    required this.directoryPath,
  });
}

class _PlannedScaffoldFile {
  final String scaffoldLabel;
  final String content;

  const _PlannedScaffoldFile({
    required this.scaffoldLabel,
    required this.content,
  });
}

class _ScaffoldContribution {
  final String? staticSourcePath;
  final String? templateSourcePath;
  final List<String> partSourcePaths;

  const _ScaffoldContribution({
    this.staticSourcePath,
    this.templateSourcePath,
    this.partSourcePaths = const [],
  });

  _ScaffoldContribution copyWith({
    String? staticSourcePath,
    String? templateSourcePath,
    List<String>? partSourcePaths,
  }) {
    return _ScaffoldContribution(
      staticSourcePath: staticSourcePath ?? this.staticSourcePath,
      templateSourcePath: templateSourcePath ?? this.templateSourcePath,
      partSourcePaths: partSourcePaths ?? this.partSourcePaths,
    );
  }
}

class _EditorConfigSections {
  final List<String> order;
  final Map<String, List<String>> linesBySection;

  const _EditorConfigSections({
    required this.order,
    required this.linesBySection,
  });
}

class _ParsedPart {
  final List<String> metadata;
  final String body;

  const _ParsedPart({required this.metadata, required this.body});
}
