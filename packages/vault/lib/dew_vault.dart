library;

export 'src/dew_vault_base.dart';

import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import 'package:dew_vault/src/dew_vault_base.dart';
import 'package:dew_vault/src/vault_init_hook.dart';

/// Registers all Vault commands and init hooks into [registry].
void registerCommands(
  CommandRegistry registry, {
  FileSystem fs = const LocalFileSystem(),
}) {
  registry.register(VaultCommand());
  registry.registerInitHook(VaultInitHook(fs: fs));
}
