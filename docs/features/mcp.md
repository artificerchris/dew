# Dew Model Context Protocol (MCP) Server

The Dew Model Context Protocol (MCP) Server is a feature that allows AI agents to interact with your project. This enables you to integrate AI capabilities into your project management workflow, such as automated task creation, progress tracking, and more.

## Package structure

The MCP feature is split across two packages to keep concerns separate:

- **`packages/core`** defines the `McpToolProvider` interface. Any feature package that wants to expose tools to AI agents implements this interface — without needing to depend on the MCP server itself.
- **`packages/mcp`** implements the actual server. It collects all registered `McpToolProvider` implementations and serves them over the configured host and port. Only the `cli` package depends on `packages/mcp`; feature packages like `kanban` remain decoupled from the transport layer.

## Configuration

The MCP server is configured under the `mcp` key in `.project/dew.yaml`. By default it runs on `localhost` at port `8080`.

```yaml
dew:
  mcp:
    host: "localhost"
    port: 8080
```

See the [Configuration documentation](../config.md) for full details.
