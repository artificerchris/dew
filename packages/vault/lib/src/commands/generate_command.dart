import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../command_output.dart';
import '../vault_config.dart';
import '../vault_generators.dart';

class GenerateCommand extends DewCommand with DewToolCommand {
  final FileSystem _fs;

  GenerateCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs {
    argParser
      ..addOption(
        'generator',
        abbr: 'g',
        mandatory: true,
        help: 'Generator ID.',
      )
      ..addMultiOption(
        'arg',
        help: 'Generator option as key=value. Repeat as needed.',
      )
      ..addOption(
        'format',
        defaultsTo: 'default',
        allowed: ['default', 'json'],
        help: 'Output format for this command.',
      );
  }

  @override
  final String name = 'generate';

  @override
  final String description = 'Generate a new secret value using a built-in generator.';

  @override
  final String toolName = 'vault_generate_secret';

  @override
  Future<String> callAsTool(Map<String, dynamic> args) async {
    final format = formatFromArgs(args);
    final generator = requireStringArg(args, 'generator');
    final rawOverrides = parseGeneratorOptionPairs(args['arg']);
    final context = await ProjectContext.find(fs: _fs);
    final configuredGenerators = context.config.vault.generators;

    final value = VaultGenerators.generateByName(
      nameOrType: generator,
      generators: configuredGenerators,
      options: rawOverrides,
    );

    return renderVaultOutput(
      format: format,
      message: value,
      json: {
        'generator': generator,
        'options': rawOverrides,
        'value': value,
      },
    );
  }

}
