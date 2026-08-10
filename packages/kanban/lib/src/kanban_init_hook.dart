import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'kanban_config.dart';

class KanbanInitHook implements DewInitHook {
  final FileSystem _fs;

  KanbanInitHook({this._fs = const LocalFileSystem()});

  @override
  Future<void> onInit(
    String projectRoot,
    DewConfig config,
    DewInitOptions options,
  ) async {
    final kanbanConfig = config.kanban;
    final kanbanRoot = p.join(projectRoot, '.project', 'kanban');

    // Column directories.
    for (final column in kanbanConfig.columns) {
      await _createDir(p.join(kanbanRoot, column.id), options.gitkeep);
    }

    // Archive and attachments directories.
    await _createDir(p.join(kanbanRoot, 'archive'), options.gitkeep);
    await _createDir(p.join(kanbanRoot, 'attachments'), options.gitkeep);
  }

  Future<void> _createDir(String path, bool gitkeep) async {
    final dir = _fs.directory(path);
    final existed = await dir.exists();
    await dir.create(recursive: true);
    final rel = '.project/kanban/${p.basename(path)}';
    if (existed) {
      print('  found   $rel/');
    } else {
      print('  created $rel/');
      if (gitkeep) {
        await _fs.file(p.join(path, '.gitkeep')).writeAsString('');
        print('  created $rel/.gitkeep');
      }
    }
  }
}
