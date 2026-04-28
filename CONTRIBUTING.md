# Contributing to Dew

Thank you for your interest in contributing! This guide covers everything you need to get set up and start making changes.

## Prerequisites

- **Dart SDK ^3.11.4** — verify with `dart --version`
- **Melos** (optional, for workspace scripts) — `dart pub global activate melos`

## Clone & setup

```bash
git clone https://github.com/artificery-dev/dew.git
cd dew
dart pub get
```

## Running the CLI locally

```bash
dart run packages/cli/bin/dew.dart kanban --help
```

## Running tests

```bash
dart test packages/core/test/
dart test packages/kanban/test/
dart test packages/mcp/test/
```

## Linting and formatting

```bash
dart analyze
dart format .
```

Fix any analysis warnings before opening a PR. The project uses the rules defined in `analysis_options.yaml`.

## Branch strategy

| Branch    | Purpose                                                 |
| --------- | ------------------------------------------------------- |
| `main`    | Stable, released code. Only merged into from `develop`. |
| `develop` | Integration branch. All PRs target this branch.         |
| `feat/*`  | Feature branches cut from `develop`.                    |
| `fix/*`   | Bug-fix branches cut from `develop`.                    |

**Workflow:**

1. Cut a feature branch from `develop`: `git checkout -b feat/my-feature develop`
2. Make your changes, add tests, run `dart analyze && dart format .`
3. Open a PR targeting `develop`
4. Releases are prepared on `develop` and merged to `main`

## Adding a new kanban command

Follow these three steps to add a command that is simultaneously a CLI subcommand and an MCP tool:

### 1. Create the command class

Create `packages/kanban/lib/src/commands/my_command.dart` implementing `DewToolCommand`:

```dart
import 'package:args/command_runner.dart';
import 'package:dew_core/dew_core.dart';

class MyCommand extends DewCommand with DewToolCommand {
  @override
  final String name = 'my-command';

  @override
  final String description = 'Does something useful.';

  MyCommand() {
    argParser.addOption('id', mandatory: true, help: 'Ticket ID.');
  }

  @override
  Future<void> run() async {
    final id = argResults!['id'] as String;
    // implementation
  }
}
```

The `DewToolCommand` mixin automatically derives the MCP tool JSON Schema from
the `ArgParser` — no extra registration work needed.

### 2. Register in the kanban base

Add your command in `packages/kanban/lib/src/dew_kanban_base.dart` alongside the existing commands:

```dart
addSubcommand(MyCommand());
```

### 3. Add tests

Add tests in `packages/kanban/test/my_command_test.dart`. Use the existing command tests as a reference for how to set up a `ProjectContext` with an in-memory filesystem.

```bash
dart test packages/kanban/test/my_command_test.dart
```

## Project structure

```text
packages/
├── cli/       — Entry point; wires all packages together
├── core/      — DewCommand, DewToolCommand, CommandRegistry, DewConfig
├── kanban/    — All kanban commands and storage logic
└── mcp/       — MCP server; reads tools from CommandRegistry
```
