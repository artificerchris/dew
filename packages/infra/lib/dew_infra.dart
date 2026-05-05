library;

export 'src/dew_infra_base.dart';
export 'src/infra_repository.dart';
export 'src/infra_runtime.dart';
export 'src/service_manifest.dart';

import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import 'src/dew_infra_base.dart';

/// Registers all infrastructure commands into [registry].
void registerCommands(
  CommandRegistry registry, {
  FileSystem fs = const LocalFileSystem(),
}) {
  registry.register(InfraCommand(fs: fs));
}
