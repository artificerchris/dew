import 'package:dew_core/dew_core.dart';
import 'package:dew_runner/dew_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _testConfig = '''
dew:
  plugins:
    directory: /project/.config/dew/plugins
''';

void main() {
  group('Run command registration', () {
    test('registerCommands adds run command', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((command) => command.name), contains('run'));
    });

    test('registerCommands adds plugins command', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      expect(registry.commands.map((command) => command.name), contains('plugins'));
    });

    test('plugins command has list subcommand', () {
      final registry = CommandRegistry();
      registerCommands(registry);
      final pluginsCommand = registry.commands.firstWhere(
        (command) => command.name == 'plugins',
      );
      expect(pluginsCommand.subcommands.keys, contains('list'));
    });
  });

  group('Runner config', () {
    test('runner config reads dew.plugins.directory', () {
      final config = DewConfig.fromYaml(loadYaml(_testConfig) as YamlMap);
      expect(config.runner.pluginDirectory, '/project/.config/dew/plugins');
    });
  });
}
