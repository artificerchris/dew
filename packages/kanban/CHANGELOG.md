# Changelog

## 0.4.0 — 2026-05-05

Release alignment for the `0.4.0` Dew package set.

- Updated the `dew_core` dependency constraint for the infra release.
- Applied analyzer fixes for current Dart lint recommendations.

## 0.1.0 — 2026-04-25

Initial release.

- 16 kanban CLI subcommands: `create`, `list`, `move`, `get`, `update`, `delete`, `archive`, `unarchive`, `link`, `unlink`, `comment`, `search`, `board`, `stats`, `config`, `tui`
- Interactive TUI with board view, ticket detail, inline editor, and help overlay
- Full MCP tool definitions for all commands
- Git-native file-based storage (Markdown + YAML frontmatter)
- Configurable columns, ticket types, labels, milestones, and transitions
