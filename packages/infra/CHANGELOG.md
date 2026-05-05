# Changelog

## 0.4.0 — 2026-05-05

Initial public release.

- Added infrastructure service discovery from `.project/infrastructure/services`.
- Added YAML service manifests with support for multiple Podman Quadlet files.
- Added manifest validation, JSON Schema validation, configuration payloads, and
  initialization payloads.
- Added Podman Quadlet install, uninstall, up, down, restart, status, logs, and
  delete operations behind a container runtime boundary.
- Added MCP tools for every `dew infra` CLI path.
