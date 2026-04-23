import 'package:args/command_runner.dart';

/// Base class for all Dew CLI commands.
///
/// Feature packages extend this class to provide their commands, then register
/// them via [CommandRegistry] so the CLI can assemble them at startup.
abstract class DewCommand extends Command<void> {}

/// Holds the [DewCommand]s registered by feature packages.
///
/// The CLI creates an instance, passes it to each package's
/// `registerCommands` function, then iterates [commands] to populate a
/// [CommandRunner].
class CommandRegistry {
  final List<DewCommand> _commands = [];

  /// Adds [command] to the registry.
  void register(DewCommand command) => _commands.add(command);

  /// An unmodifiable view of all registered commands.
  List<DewCommand> get commands => List.unmodifiable(_commands);
}
