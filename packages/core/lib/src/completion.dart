import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'dew_core_base.dart';

/// Shell completion helpers.
class CompletionCommand extends DewCommand {
  CompletionCommand({FileSystem fs = const LocalFileSystem()}) {
    addSubcommand(_ScaffoldCompletionCommand(fs: fs));
  }

  @override
  final String name = 'completion';

  @override
  final String description = 'Shell completion helpers for Dew commands.';
}

class _ScaffoldCompletionCommand extends DewCommand {
  final FileSystem _fs;

  _ScaffoldCompletionCommand({required this._fs}) {
    argParser
      ..addOption(
        'prefix',
        help: 'Optional prefix filter for scaffold names.',
      )
      ..addOption(
        'root',
        help:
            'Optional scaffold root override. Defaults to '
            r'${XDG_CONFIG_HOME:-~/.config}/dew/scaffolds.',
      );
  }

  @override
  final String name = 'scaffolds';

  @override
  final String description = 'List available scaffold names for completion.';

  @override
  Future<void> run() async {
    final prefix = (argResults!['prefix'] as String?)?.trim() ?? '';
    final rootArg = (argResults!['root'] as String?)?.trim();
    final root = rootArg == null || rootArg.isEmpty
        ? _defaultScaffoldRoot()
        : p.normalize(rootArg);
    final dir = _fs.directory(root);
    if (!await dir.exists()) return;

    final names = await dir
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => prefix.isEmpty || name.startsWith(prefix))
        .toList();

    names.sort();
    for (final name in names) {
      print(name);
    }
  }
}

String _defaultScaffoldRoot() {
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    return p.join(xdg, 'dew', 'scaffolds');
  }
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return p.join('~', '.config', 'dew', 'scaffolds');
  return p.join(home, '.config', 'dew', 'scaffolds');
}
