import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

class VaultInitHook implements DewInitHook {
  final FileSystem _fs;

  VaultInitHook({FileSystem fs = const LocalFileSystem()}) : _fs = fs;

  @override
  Future<void> onInit(
    String projectRoot,
    DewConfig config,
    DewInitOptions options,
  ) async {
    final vaultDir = p.join(projectRoot, '.project', 'vault');
    final secretDir = p.join(projectRoot, '.project', 'secrets');

    await _createDir(vaultDir, options.gitkeep);
    await _createDir(secretDir, options.gitkeep);
  }

  Future<void> _createDir(String path, bool withGitkeep) async {
    final dir = _fs.directory(path);
    final existed = await dir.exists();
    await dir.create(recursive: true);
    final relPath = p.join('.project', p.basename(path));
    if (existed) {
      print('  found   $relPath/');
    } else {
      print('  created $relPath/');
      if (withGitkeep) {
        await _fs.file(p.join(path, '.gitkeep')).writeAsString('');
        print('  created $relPath/.gitkeep');
      }
    }
  }
}
