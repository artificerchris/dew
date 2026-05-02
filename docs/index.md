# Dew Documentation

Welcome to the documentation for the Dew project management tool!

## Contents

- [Configuration](./config.md) — Configuring Dew via `dew.yaml`

### Features

- [Kanban Board](./features/kanban.md) — Visualize and manage tasks in a column-based workflow
- [MCP Server](./features/mcp.md) — AI agent integration via the Model Context Protocol

## Package Architecture

Dew is structured as a Dart workspace with the following packages:

| Package           | Description                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------------- |
| `packages/cli`    | The `dew` command-line tool. Wires all packages together at startup.                         |
| `packages/core`   | Shared foundation: `DewCommand`, `DewToolCommand` mixin, `CommandRegistry`, and `DewConfig`. |
| `packages/kanban` | Kanban board logic. Each command automatically registers itself as an MCP tool.              |
| `packages/mcp`    | The MCP server. Collects tools from `CommandRegistry` and serves them over stdio.            |

### How commands become MCP tools

Every CLI command that mixes in `DewToolCommand` is automatically registered as an MCP tool — no separate registration needed. The mixin derives the JSON Schema for the tool's input from the command's own `ArgParser`, so argument definitions are written exactly once.

```text
ArgParser definition
      │
      ├─► dew kanban create   (human CLI)
      └─► kanban_create_ticket (MCP tool with schema)
```

### Config architecture

`DewConfig` in `core` is a thin wrapper around the raw YAML map. Feature packages add typed accessors via Dart extensions:

- `dew_kanban` defines `KanbanDewConfig` — exposes `context.config.kanban`
- `dew_mcp` currently has no project-level config values

This keeps feature-specific config classes out of `core`.
