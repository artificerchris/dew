# Changelog

## 0.4.0 — 2026-05-05

Infra and MCP provider release.

- Extended `CommandRegistry.mcpTools` to collect extra tools from
  `McpToolProvider` command classes.
- Kept `InitCommand` analyzer-clean with the Dart SDK `3.12` lint set.

## 0.1.0 — 2026-04-25

Initial release.

- `DewCommand` base class with arg-parser-driven CLI and MCP tool dual-mode
- `DewToolCommand` mixin for commands that expose an MCP tool
- `CommandRegistry` for feature-package command registration
- `ProjectContext` for locating and loading `.project/dew.yaml`
- `schemaFromArgParser` helper for generating JSON Schema from `ArgParser`
