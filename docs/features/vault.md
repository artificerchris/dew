# Dew Vault Secret Manager

Dew Vault is a secret manager for your projects. It helps you keep secrets out of
version control by storing each secret as an encrypted file under `.project/vault`.
By default the vault password is stored in `.project/secrets/dew.vault.password`.

## Config

Vault settings live in `.project/dew.yaml` under `dew.vault`.

```yaml
dew:
  vault:
    password_file: .project/secrets/dew.vault.password
    storage_dir: .project/vault
    generators:
      postgres_password:
        type: random_password
        description: Generate random PostgreSQL passwords.
        config:
          length: 64
          include_symbols: true
      jwt_secret:
        type: random_token
        description: Generate JWT signing secrets.
        config:
          encoding: base64
          bytes: 48
      service_uuid:
        type: uuid_v4
        description: Generate stable-looking unique IDs.
```

`generators` maps a generator name (for example `postgres_password`) to a built-in
generator definition. Values under `config` are defaults and can be overridden per
run or stored in secret rotation metadata.

Built-in generator types are resolved inside Dew, so secrets can be generated
without depending on host binaries.

## Commands

Most commands support `--format [default|json]` (default is `default`) for
machine-friendly automation.

### Initialize Vault

Initialize the vault storage and metadata.

```bash
dew vault init

dew vault init --password-file .project/secrets/dew.vault.password
```

### List all secrets

List stored secrets.

```bash
dew vault list
dew vault list --format json
```

### Set a secret

`set` stores or replaces a secret and optional metadata.

```bash
dew vault set <secret-name> # Prompts for secret value
dew vault set <secret-name> --env ENV_VAR_NAME # Uses value from environment variable
dew vault set <secret-name> --file /path/to/secret.txt # Uses value from file
echo "secret value" | dew vault set <secret-name> # Uses piped stdin

# Include metadata for automated rotation requirements
dew vault set DB_PASSWORD --metadata '{"rotation":{"enabled":true,"generator":"postgres_password","length":64}}'
dew vault set DB_PASSWORD --metadata-file .project/vault/db_password.meta.json
```

### Get a secret

`get` retrieves a secret by name.

```bash
dew vault get <secret-name>
dew vault get <secret-name> --format json
```

### Update a secret

`update` patches secret metadata and/or value. Omit value source flags to edit
metadata only.

```bash
dew vault update <secret-name> --env ROLLED_PASSWORD
dew vault update <secret-name> --metadata '{"rotation":{"enabled":false}}'
dew vault update <secret-name> --metadata-file .project/vault/db_password.meta.json
```

### Rename a secret

`rename` changes a secret identifier while preserving value and metadata.

```bash
dew vault rename OLD_NAME NEW_NAME
dew vault rename OLD_NAME NEW_NAME --format json
```

### Generate a secret value

`generate` runs a built-in generator without writing to the vault by default.

```bash
dew vault generate postgres_password --length 64 --include_symbols
dew vault generate jwt_secret --bytes 64 --encoding base64
dew vault generate postgres_password --service payments --username app_user --format json
```

Pipe generated output directly into `set` when needed:

```bash
dew vault generate postgres_password --service payments | dew vault set DB_PASSWORD
```

### Rotate secrets

`rotate` rewraps secrets with a new vault password when run without a name.
When run with a secret name, it rotates only that secret. For a secret with rotation
metadata (`rotation.enabled: true` and `rotation.generator`), Dew invokes that
configured built-in generator using the provided rotation values.

```bash
dew vault rotate
dew vault rotate <secret-name>
dew vault rotate <secret-name> --format json
```

### Delete a secret

`delete` removes a secret and metadata from the vault.

```bash
dew vault delete <secret-name>
dew vault delete <secret-name> --format json
```

### Metadata format for rotation-aware secrets

Attach arbitrary metadata and include rotation policy details. Example shape:

```json
{
  "rotation": {
    "enabled": true,
    "generator": "postgres_password",
    "service": "payments",
    "username": "app_user",
    "length": 64
  },
  "notes": "Rotate monthly and update app config via sidecar"
}
```

Rotation flow:

1. Define a built-in generator in `dew.yaml` under `dew.vault.generators`.
2. Attach `rotation.generator` and generator args to the secret metadata.
3. Run `dew vault rotate <secret-name>` to rotate one secret, or `dew vault rotate`
   to rotate all configured secrets.
