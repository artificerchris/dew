# Dew Model Context Protocol (MCP) Server

The Dew Model Context Protocol (MCP) Server is a feature that allows AI agents to interact with your project. This enables you to integrate AI capabilities into your project management workflow, such as automated task creation, progress tracking, and more.

## Package structure

The MCP feature is split across two packages to keep concerns separate:

- **`packages/core`** defines the `McpToolProvider` interface. Any feature package that wants to expose tools to AI agents implements this interface — without needing to depend on the MCP server itself.
- **`packages/mcp`** implements the actual server. It collects all registered `McpToolProvider` implementations and serves them over stdio using the [dart\_mcp](https://pub.dev/packages/dart_mcp) package. Only the `cli` package depends on `packages/mcp`; feature packages like `kanban` remain decoupled from the transport layer.

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

| Tool                      | Description                                              |
| ------------------------- | -------------------------------------------------------- |
| `kanban_create_ticket`    | Create a new kanban ticket                               |
| `kanban_list_tickets`     | List tickets, optionally filtered by column or type      |
| `kanban_get_ticket`       | Get a ticket by ID                                       |
| `kanban_update_ticket`    | Update one or more fields on an existing ticket          |
| `kanban_delete_ticket`    | Delete a ticket by ID                                    |
