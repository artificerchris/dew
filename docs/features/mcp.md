# Dew Model Context Protocol (MCP) Server

The Dew Model Context Protocol (MCP) Server is a feature that allows AI agents to interact with your project. This enables you to integrate AI capabilities into your project management workflow, such as automated task creation, progress tracking, and more.

The MCP server is implemented in the `packages/core` package, so other packages can interact with it. You can configure the MCP server's host and port in the `dew.yaml` configuration file under the `mcp` section. By default, the server will run on `localhost` at port `8080`.
