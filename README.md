# Dew

[![pub package](https://img.shields.io/pub/v/dew.svg)](https://pub.dev/packages/dew)

**Dew** is a git-native project management CLI for developers who want a kanban board that lives in their repository and talks to AI agents. Tickets are plain Markdown files with YAML frontmatter — diff-friendly, grep-able, and version-controlled alongside your code.

## Features

### Kanban CLI

16 subcommands cover the full lifecycle of a ticket:

```
create  list    get      update   delete  move
search  comment archive  unarchive link   unlink
stats   board   config   tui
```

Tickets are stored as `.project/kanban/<column>/<ID>.md` files. Labels, milestones, typed bidirectional links, and inline comments are all first-class citizens. See the [Kanban documentation](./docs/features/kanban.md) for the full command reference.

### Interactive TUI

`dew kanban tui` opens a full Trello-style terminal board with three modes:

- **Board** — navigate columns and tickets, create/edit/move/archive/delete, live search filter
- **Detail** — scrollable view of a ticket's body and comments
- **Editor** — in-terminal modal for editing all ticket fields; opens `$VISUAL`/`$EDITOR` for the body

The TUI auto-refreshes when ticket files change on disk, so it stays in sync whether you're editing files directly or an AI agent is updating them.

### MCP Server

`dew mcp serve` starts an MCP-compliant stdio server that exposes every kanban command as an MCP tool. AI agents (GitHub Copilot, Claude, etc.) can create tickets, move cards, search, and comment — using the exact same logic as the CLI. No separate tool definitions needed: every command that mixes in `DewToolCommand` is registered automatically. See the [MCP documentation](./docs/features/mcp.md).

## Installation

```bash
dart pub global activate dew
```

Requires Dart SDK ^3.11.4.

## Quick start

```bash
# Scaffold a new project (creates .project/dew.yaml)
dew init .

# Create your first ticket
dew kanban create --title "My first ticket" --type task

# Open the interactive board
dew kanban tui
```

## Configuration

Dew reads `.project/dew.yaml` for board columns, ticket types, ID prefix, and MCP server settings. Running `dew init .` generates this file with defaults. See the [Configuration documentation](./docs/config.md) for the full schema reference.

## Documentation

- [Full documentation index](./docs/index.md)
- [Kanban board](./docs/features/kanban.md) — CLI commands, TUI keybindings, ticket format
- [MCP server](./docs/features/mcp.md) — AI agent integration
- [Configuration reference](./docs/config.md)
