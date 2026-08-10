# dew_vault

Vault feature package for the [Dew](https://github.com/artificerchris/dew) project
management tool.

This package provides the `dew vault` command surface and registers Vault commands
as MCP tools through `DewToolCommand`.

## Status

This package implements encrypted secret storage, rotation-aware metadata, and
command handlers exposed as MCP tools.

## Features

- Encrypted secret storage under `.project/vault` using AES-GCM + PBKDF2.
- Vault password stored at `.project/secrets/dew.vault.password` by default.
- Configurable generators for secret rotation in `dew.vault.generators`.
- Built-in generator-backed `generate` command.
- Metadata-aware rotation and metadata persistence for rotation policy configuration.
- Rotation support:
  - `vault rotate` rotates the vault password and rewraps every secret.
  - `vault rotate --name <name>` regenerates a single secret value (via metadata-defined
    generator when available).

## Commands

- `dew vault init`
- `dew vault get`
- `dew vault set`
- `dew vault update`
- `dew vault rename`
- `dew vault rotate`
- `dew vault generate`
- `dew vault list`
- `dew vault delete`

Run `dew vault <command> --format json` for machine-friendly output.

## License

MIT — see [LICENSE](LICENSE).

## Example metadata

```yaml
rotation:
  generator: postgres_password
  length: 48
  include_symbols: false
```

Store it with `--metadata` or `--metadata-file` on `dew vault set`/`dew vault update`.
