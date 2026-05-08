import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('InitCommand scaffolds', () {
    late MemoryFileSystem fs;
    late CommandRunner<void> runner;

    setUp(() {
      fs = MemoryFileSystem();
      runner = CommandRunner<void>('dew', 'test')
        ..addCommand(InitCommand(const [], fs: fs));
    });

    test('creates empty default scaffold root when missing', () async {
      fs.directory('/workspace').createSync(recursive: true);

      await runner.run(['init', '--path', '/workspace']);

      expect(
        fs.directory('/home/artificer/.config/dew/scaffolds/_default').existsSync(),
        isTrue,
      );
      expect(fs.file('/workspace/.project/dew.yaml').existsSync(), isTrue);
    });

    test('applies base then merge then strict in order', () async {
      fs.directory('/workspace').createSync(recursive: true);
      fs
          .directory('/home/artificer/.config/dew/scaffolds/base')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/base/AGENTS.md')
          .writeAsStringSync('base');
      fs
          .file('/home/artificer/.config/dew/scaffolds/base/.editorconfig.liquid')
          .writeAsStringSync('root = true\n\n[*]\nindent_size = {{ 2 }}\n');
      fs
          .directory('/home/artificer/.config/dew/scaffolds/base/.project')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/base/.project/.gitignore')
          .writeAsStringSync('/should/not/override\n');

      fs
          .directory('/home/artificer/.config/dew/scaffolds/merge')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/merge/AGENTS.md')
          .writeAsStringSync('merge');
      fs
          .file('/home/artificer/.config/dew/scaffolds/merge/.editorconfig.part.liquid')
          .writeAsStringSync(
            '# dew-part: editorconfig\n'
            '# id: dart-core\n'
            '# mode: merge\n'
            '# anchor: eof\n'
            '\n'
            '[*.dart]\n'
            'indent_size = 2\n',
          );

      fs
          .directory('/home/artificer/.config/dew/scaffolds/strict')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/strict/.gitignore')
          .writeAsStringSync('strict');

      await runner.run([
        'init',
        '--path',
        '/workspace',
        '--scaffold',
        'base',
        '--scaffold-merge',
        'merge',
        '--scaffold-strict',
        'strict',
      ]);

      expect(
        fs.file('/workspace/AGENTS.md').readAsStringSync(),
        'merge',
      );
      expect(
        fs.file('/workspace/.editorconfig').readAsStringSync(),
        allOf(
          contains('#region dart-core'),
          contains('# id: dart-core'),
          contains('[*.dart]\nindent_size = 2'),
          contains('#endregion dart-core'),
        ),
      );
      expect(
        fs.file('/workspace/.project/.gitignore').readAsStringSync(),
        contains('/secrets/'),
      );
      expect(fs.file('/workspace/.gitignore').readAsStringSync(), 'strict');
    });

    test('strict scaffold fails on collisions', () async {
      fs.directory('/workspace').createSync(recursive: true);
      fs
          .directory('/home/artificer/.config/dew/scaffolds/base')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/base/AGENTS.md')
          .writeAsStringSync('base');

      fs
          .directory('/home/artificer/.config/dew/scaffolds/strict')
          .createSync(recursive: true);
      fs
          .file('/home/artificer/.config/dew/scaffolds/strict/AGENTS.md')
          .writeAsStringSync('strict');

      await expectLater(
        runner.run([
          'init',
          '--path',
          '/workspace',
          '--scaffold',
          'base',
          '--scaffold-strict',
          'strict',
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('path-like scaffold input fails when missing', () async {
      fs.directory('/workspace').createSync(recursive: true);

      await expectLater(
        runner.run([
          'init',
          '--path',
          '/workspace',
          '--scaffold',
          './missing',
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
