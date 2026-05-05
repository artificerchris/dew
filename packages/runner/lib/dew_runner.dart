library;

export 'src/dew_runner_base.dart';
export 'src/runner_config.dart';

import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import 'package:dew_runner/src/dew_runner_base.dart';

/// Registers all runner commands into [registry].
void registerCommands(
  CommandRegistry registry, {
  FileSystem fs = const LocalFileSystem(),
}) {
  registry.register(PluginsCommand(fs: fs));
  registry.register(RunCommand(fs: fs));
}
