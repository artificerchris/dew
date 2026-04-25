# Changelog

## 1.0.0 — 2026-04-25

Initial stable release.

- `DewCommand` base class with arg-parser-driven CLI and MCP tool dual-mode
- `DewToolCommand` mixin for commands that expose an MCP tool
- `CommandRegistry` for feature-package command registration
- `ProjectContext` for locating and loading `.project/dew.yaml`
- `schemaFromArgParser` helper for generating JSON Schema from `ArgParser`
