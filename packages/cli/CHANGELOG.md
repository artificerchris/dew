# Changelog

## 0.4.2 — 2026-05-08

- Add scaffold templating improvements, docs, and release polish.

## 0.4.1 — 2026-05-05

Patch release.

- Restored the pubspec `executables` declaration so
  `dart pub global activate dew` installs the `dew` launcher.

## 0.4.0 — 2026-05-05

Infra release.

- Added the `dew infra` command group to the CLI.
- Registered the infra package alongside kanban, MCP, and vault packages.
- Updated CLI dependencies for the `0.4.0` package set.

## 0.1.0 — 2026-04-25

Initial release.

- `dew init` — initialise a Dew project
- `dew kanban` — full kanban board management (16 subcommands + TUI)
- `dew mcp serve` — start the MCP server for AI assistant integration
