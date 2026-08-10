# Changelog

## 0.4.2 — 2026-05-08

- Add scaffold templating improvements, docs, and release polish.

## 0.4.0 — 2026-05-05

Release alignment for the `0.4.0` Dew package set.

- Updated the `dew_core` dependency constraint for the infra release.
- Published vault with the SDK floor and config path fixes from the development
  branch.
- Applied analyzer fixes for current Dart lint recommendations.

## 0.3.0 — 2026-05-03

Implemented vault command behavior end-to-end and completed release-readiness features.

- Replaced all vault command stubs with real implementations.
- Added support for command aliases as explicit commands: `set`, `get`, `update`, `rename`,
  `rotate`, `generate`, `list`, `delete`, and `init`.
- Added `--format [default|json]` output handling for supported commands.
- Added rotation metadata support and integrated metadata-driven rotation policy storage.
- Added configurable built-in generators under `dew.vault.generators`.
- Added `vault generate <generator-name>` command for local generation without shelling out.
- Added `--name`-driven single-secret rotation and vault-wide password rotation behavior.
- Added metadata parsing via `--metadata` and `--metadata-file`.
- Added encryption-backed vault storage and password-rotation plumbing.
- Added full command coverage tests for `dew_vault`, including generator, init, rotate,
  rename, metadata, env input, and output format paths.

## 0.2.0 — 2026-05-03

Initial feature stub package for vault support.

- Added `dew vault` command registration and MCP tool wiring.
- Added vault subcommands for init/list/get/set/update/rename/rotate/generate/delete.
- Added `VaultInitHook` scaffold for `.project/vault` and `.project/secrets`.
