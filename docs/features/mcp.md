# Dew Model Context Protocol (MCP) Server

The Dew Model Context Protocol (MCP) Server is a feature that allows AI agents to interact with your project. This enables you to integrate AI capabilities into your project management workflow, such as automated task creation, progress tracking, and more.

## Package structure

The MCP feature is split across two packages to keep concerns separate:

- **`packages/core`** defines the `DewToolCommand` mixin and `McpToolProvider`
  interface. Commands that mix in `DewToolCommand` are automatically registered
  as MCP tools, and commands that implement `McpToolProvider` can expose extra
  path-specific tools.
- **`packages/mcp`** implements the actual server. It reads the list of tools from `CommandRegistry` and
  serves them over stdio using the [dart\_mcp](https://pub.dev/packages/dart_mcp) package. Only the `cli`
  package depends on `packages/mcp`; feature packages like `kanban` remain decoupled from the transport layer.

## Configuration

The MCP server is configured under the `mcp` key in `.project/dew.yaml`. By default it runs on `localhost` at port `8080`.

```yaml
dew:
  mcp:
    host: "localhost"
    port: 8080
```

See the [Configuration documentation](../config.md) for full details.

## Running the server

The MCP server uses **stdio transport** — the MCP client launches it as a child process and communicates over stdin/stdout. Because of this, the process must have clean stdout (no decorative output). `melos run` pollutes stdout with its own log lines, which corrupts the JSON-RPC channel.

### Step 1 — Compile to a native binary

```text
melos run compile
```

This produces `.project/toolchain/bin/dew` (or `.project/toolchain/bin/dew.exe` on Windows).

### Step 2 — Configure your MCP client

Point your MCP client at the compiled binary. For example, in VS Code's MCP configuration:

```json
{
  "mcpServers": {
    "dew": {
      "command": "/absolute/path/to/dew/.project/toolchain/bin/dew",
      "args": ["mcp", "serve"]
    }
  }
}
```

The server logs its startup message to **stderr** so it never interferes with the JSON-RPC channel on stdout.

## Available tools

The following tools are registered by the `kanban` package:

| Tool                      | Description                                                             |
| ------------------------- | ----------------------------------------------------------------------- |
| `kanban_create_ticket`    | Create a new kanban ticket                                              |
| `kanban_list_tickets`     | List tickets, optionally filtered by column or type                     |
| `kanban_get_ticket`       | Get details of a specific ticket by ID                                  |
| `kanban_update_ticket`    | Update one or more fields on an existing ticket                         |
| `kanban_delete_ticket`    | Delete a ticket permanently (also removes its attachment directory)     |
| `kanban_move_ticket`      | Move a ticket to a different column                                     |
| `kanban_search_tickets`   | Full-text search across ticket titles, bodies, and comments             |
| `kanban_add_comment`      | Append a comment to a ticket                                            |
| `kanban_get_config`       | Return the current kanban config (columns, types, prefix)               |
| `kanban_stats`            | Show ticket counts grouped by column and type                           |
| `kanban_link_tickets`     | Link two tickets with a typed relationship (bidirectional)              |
| `kanban_unlink_tickets`   | Remove a link between two tickets (both sides)                          |

The following tools are registered by the `infra` package:

| Tool                         | Description                                      |
| ---------------------------- | ------------------------------------------------ |
| `infra_list_services`        | List infrastructure services                     |
| `infra_show_service`         | Show manifest and runtime details                |
| `infra_validate_services`    | Validate one service or all services             |
| `infra_configure_service`    | CLI-default configure path placeholder           |
| `infra_configure_schema`     | Show the configure JSON Schema                   |
| `infra_configure_show`       | Show the active configure payload                |
| `infra_configure_apply`      | Apply configure payload values                   |
| `infra_init_service`         | CLI-default init path placeholder                |
| `infra_init_schema`          | Show the init JSON Schema                        |
| `infra_init_run`             | Write an initialization payload                  |
| `infra_install_service`      | Install service Quadlets                         |
| `infra_uninstall_service`    | Uninstall service Quadlets                       |
| `infra_up_service`           | Install, reload, and start services              |
| `infra_down_service`         | Stop services                                    |
| `infra_restart_service`      | Restart services                                 |
| `infra_status_service`       | Show service runtime status                      |
| `infra_logs`                 | Read service logs                                |
| `infra_delete_service`       | Delete declared runtime artifacts                |

### Link types

`kanban_link_tickets` requires a `--type` argument. The inverse is written automatically on the target ticket.

| Type              | Inverse           | Symmetric? |
| ----------------- | ----------------- | ---------- |
| `blocks`          | `is_blocked_by`   | No         |
| `is_blocked_by`   | `blocks`          | No         |
| `relates_to`      | `relates_to`      | Yes        |
| `duplicates`      | `is_duplicated_by`| No         |
| `is_duplicated_by`| `duplicates`      | No         |
| `parent_of`       | `child_of`        | No         |
| `child_of`        | `parent_of`       | No         |
