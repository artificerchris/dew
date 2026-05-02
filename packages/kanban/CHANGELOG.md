# Changelog

## 0.2.0 — 2026-05-02

- Updated tests and fixtures for the generated config without unsupported MCP
  `host` and `port` fields.
- Bumped the `dew_core` dependency constraint to `^0.2.0`.

## 0.1.0 — 2026-04-25

Initial release.

- 16 kanban CLI subcommands: `create`, `list`, `move`, `get`, `update`, `delete`, `archive`, `unarchive`, `link`, `unlink`, `comment`, `search`, `board`, `stats`, `config`, `tui`
- Interactive TUI with board view, ticket detail, inline editor, and help overlay
- Full MCP tool definitions for all commands
- Git-native file-based storage (Markdown + YAML frontmatter)
- Configurable columns, ticket types, labels, milestones, and transitions
