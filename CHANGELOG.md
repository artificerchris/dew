# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-25

### Added

#### `dew init`

- `dew init <path>` scaffolds a new project, generating `.project/dew.yaml` with
  sensible defaults and running all module init hooks (kanban directory layout, etc.).

#### Kanban CLI (`dew kanban`)

Full set of kanban subcommands, each also registered as an MCP tool automatically:

| Subcommand  | Description                                                                  |
| ----------- | ---------------------------------------------------------------------------- |
| `create`    | Create a new ticket with title, type, column, body, labels, and milestones   |
| `list`      | List tickets filtered by column, type, label, milestone, or archived state   |
| `get`       | Fetch a single ticket by ID                                                  |
| `update`    | Update any field on a ticket (title, type, column, body, labels, milestones) |
| `delete`    | Permanently delete a ticket                                                  |
| `move`      | Move a ticket to a different column (validates column transition rules)      |
| `search`    | Full-text search across ticket titles, bodies, and comments                  |
| `comment`   | Append a comment to a ticket                                                 |
| `archive`   | Soft-delete a ticket by moving it to the archive column                      |
| `unarchive` | Restore an archived ticket to a column                                       |
| `link`      | Create a typed bidirectional link between two tickets                        |
| `unlink`    | Remove a link between two tickets                                            |
| `stats`     | Display ticket counts grouped by column and type                             |
| `board`     | Print an ASCII representation of the board                                   |
| `config`    | Print the current kanban configuration                                       |
| `tui`       | Launch the interactive terminal UI                                           |

- File-based storage: each ticket is a Markdown file with YAML frontmatter for
  metadata and inline `---` separators for comments. Column is derived from the
  containing subdirectory — not duplicated in the file.
- Typed, bidirectional ticket links: `blocks`/`is_blocked_by`, `relates_to`,
  `duplicates`/`is_duplicated_by`, `parent_of`/`child_of`. Writing one side
  automatically writes the inverse on the target ticket.
- Labels and milestones as first-class ticket fields.
- Column transition validation: enforces allowed moves between configured columns.
- `--include-archived` flag on `list` and `search` to include soft-deleted tickets.

#### Interactive TUI (`dew kanban tui`)

- Full Trello-style terminal board rendered with ANSI box-drawing characters.
- **Board mode**: pill/tab column headers, scrollable ticket list per column,
  live `?` filter/search overlay, `n` create, `e` edit, `a` archive, `D` delete,
  `c` comment, `L` link, `<`/`>` move ticket between columns, Enter open detail.
- **Detail mode**: scrollable ticket detail view with formatted body and comments.
- **Editor modal**: in-terminal overlay for editing all ticket fields — title,
  type (picker), column (picker), labels, milestones, and body. Arrow keys cycle
  selector values; Enter edits text fields or opens `$VISUAL`/`$EDITOR` for body.
- F1 help overlay in every mode showing context-sensitive keybindings.
- Auto-refresh via filesystem watching: board reloads live when ticket files
  change on disk (e.g. from another terminal or AI agent).
- SIGWINCH handling for correct redraws on terminal resize.

#### MCP Server (`dew mcp serve`)

- `dew mcp serve` starts an MCP-compliant stdio server.
- All kanban commands that implement the `DewToolCommand` mixin are automatically
  exposed as MCP tools — no separate registration required.
- JSON Schema for each tool's input is derived directly from the command's
  `ArgParser`, so argument definitions are written exactly once.
- Compiled CLI binary at `.project/toolchain/bin/dew` used by the MCP server to
  avoid stdin conflicts.

#### Core Architecture

- `DewToolCommand` mixin: mix into any `DewCommand` to register it simultaneously
  as a CLI subcommand and an MCP tool.
- `CommandRegistry`: central registry collected at startup; MCP server reads from
  this registry to enumerate available tools.
- `DewConfig` with typed extension pattern: `core` holds the raw YAML map; feature
  packages (`kanban`, `mcp`) add typed accessors via Dart extensions, keeping
  feature-specific config out of `core`.
- `ProjectDirs` with injectable filesystem abstraction (`package:file`) for
  testable path resolution.

[Unreleased]: https://github.com/artificerchris/dew/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/artificerchris/dew/releases/tag/v0.1.0
