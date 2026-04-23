# Dew Documentation

Welcome to the documentation for the Dew project management tool!

## Contents

- [Configuration](./config.md) — Configuring Dew via `dew.yaml`

### Features

- [Kanban Board](./features/kanban.md) — Visualize and manage tasks in a column-based workflow
- [MCP Server](./features/mcp.md) — AI agent integration via the Model Context Protocol

## Package Architecture

Dew is structured as a Dart workspace with the following packages:

| Package           | Description                                                                                |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `packages/cli`    | The `dew` command-line tool. Wires all packages together at startup.                       |
| `packages/core`   | Shared types (tickets, columns, config) and the `McpToolProvider` interface.               |
| `packages/kanban` | Kanban board logic. Implements `McpToolProvider` to expose its tools to the MCP server.    |
| `packages/mcp`    | The MCP server. Depends on `core`; collects and serves registered tools from all packages. |

`kanban` (and future feature packages) depend only on `core` — not on `mcp` — keeping them usable independently of the AI integration layer. The `cli` package is the only one that depends on `mcp` and is responsible for starting the server and registering all providers.
