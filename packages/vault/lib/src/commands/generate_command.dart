import 'package:dew_core/dew_core.dart';

import '../command_output.dart';

class GenerateCommand extends DewCommand with DewToolCommand {
  GenerateCommand() {
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
    final overrides = args['arg'] as List<dynamic>?;
    return renderVaultOutput(
      format: format,
      message: 'Generate stub output.',
      json: {
        'generator': generator,
        'options': overrides == null ? const <String>[] : overrides,
        'value': '<generated>',
      },
    );
  }

}
