# Dew

[![pub package](https://img.shields.io/pub/v/dew.svg)](https://pub.dev/packages/dew)

**Dew** is a git-native project management CLI for developers who want a kanban board that lives in their repository and talks to AI agents. Tickets are plain Markdown files with YAML frontmatter — diff-friendly, grep-able, and version-controlled alongside your code.

## Features

### Kanban CLI

16 subcommands cover the full lifecycle of a ticket:

```text
create  list    get      update   delete  move
search  comment archive  unarchive link   unlink
stats   board   config   tui
```

Tickets are stored as `.project/kanban/<column>/<ID>.md` files. Labels, milestones, typed bidirectional links, and inline comments are all first-class citizens. See the [Kanban documentation](./docs/features/kanban.md) for the full command reference.

### Infrastructure

`dew infra` discovers services under `.project/infrastructure/services`, validates
their manifests and schemas, and manages Podman Quadlets through systemd. The
runtime boundary is explicit so other container backends can be added later.

### Interactive TUI

`dew kanban tui` opens a full Trello-style terminal board with three modes:

- **Board** — navigate columns and tickets, create/edit/move/archive/delete, live search filter
- **Detail** — scrollable view of a ticket's body and comments
- **Editor** — in-terminal modal for editing all ticket fields; opens `$VISUAL`/`$EDITOR` for the body

The TUI auto-refreshes when ticket files change on disk, so it stays in sync whether you're editing files directly or an AI agent is updating them.

### MCP Server

`dew mcp serve` starts an MCP-compliant stdio server that exposes Dew commands
as MCP tools. AI agents (GitHub Copilot, Claude, etc.) can create tickets, move
cards, search, comment, and manage project infrastructure through the same logic
as the CLI. See the [MCP documentation](./docs/features/mcp.md).

## Installation

```bash
dart pub global activate dew
```

Requires Dart SDK ^3.12.0.

## Quick start

```bash
# Scaffold a new project (creates .project/dew.yaml)
dew init .

# Create your first ticket
dew kanban create --title "My first ticket" --type task

# Open the interactive board
dew kanban tui
```

## Scaffold templates

`dew init` supports layered user scaffolds from
`${XDG_CONFIG_HOME:-~/.config}/dew/scaffolds`:

```bash
# Apply implicit _default scaffold, then merge dart overlay
dew init --scaffold-merge dart

# Layer explicit base scaffolds and strict overlays
dew init --scaffold team --scaffold-merge dart --scaffold-strict ci
```

Template conventions:

- `filename` → static file
- `filename.liquid` → rendered base template
- `filename.part.liquid` → rendered merge fragment

See [Init and Scaffolds](./docs/features/init.md) for full behavior.

## Configuration

Dew reads `.project/dew.yaml` for board columns, ticket types, ID prefix, and MCP server settings. Running `dew init .` generates this file with defaults. See the [Configuration documentation](./docs/config.md) for the full schema reference.

## Documentation

- [Full documentation index](./docs/index.md)
- [Infrastructure](./docs/features/infra.md) — service manifests, Quadlet install, lifecycle commands
- [Init and scaffolds](./docs/features/init.md) — layered template conventions and merge behavior
- [Kanban board](./docs/features/kanban.md) — CLI commands, TUI keybindings, ticket format
- [MCP server](./docs/features/mcp.md) — AI agent integration
- [Configuration reference](./docs/config.md)
