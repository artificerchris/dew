# Dew Vault Secret Manager

Dew Vault stores project secrets as encrypted files under `.project/vault`.
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

`generators` maps a generator name to a built-in generator definition. Values
under `config` are defaults and can be overridden per command invocation or in
secret rotation metadata.

Built-in generator types are resolved inside Dew, so secrets can be generated
without depending on host binaries.

## Commands

Most commands support `--format [default|json]` (default is `default`) for
machine-friendly automation.

### Initialize Vault

Initialize vault directories and password file.

```bash
dew vault init
dew vault init --password-file .project/secrets/dew.vault.password
dew vault init --storage-dir .project/vault
```

### List all secrets

```bash
dew vault list
dew vault list --format json
```

### Set a secret

`set` stores or replaces a secret and optional metadata.

```bash
dew vault set --name DB_PASSWORD --file /path/to/secret.txt
dew vault set --name DB_PASSWORD --env ENV_VAR_NAME
```

### Get a secret

```bash
dew vault get --name DB_PASSWORD
dew vault get --name DB_PASSWORD --format json
```

### Update a secret

`update` patches secret metadata and/or value. Omit value source flags to edit
metadata only.

```bash
dew vault update --name DB_PASSWORD --metadata '{"rotation":{"enabled":true,"generator":"postgres_password","length":64}}'
dew vault update --name DB_PASSWORD --metadata-file .project/vault/db_password.meta.json
```

### Rename a secret

```bash
dew vault rename --from OLD_NAME --to NEW_NAME
dew vault rename --from OLD_NAME --to NEW_NAME --format json
```

### Generate a secret value

`generate` uses configured generators without writing to the vault by default.

```bash
dew vault generate --generator postgres_password --arg length=64 --arg include_symbols=true
dew vault generate --generator jwt_secret --arg bytes=64 --arg encoding=base64
dew vault generate --generator postgres_password --arg service=payments --arg username=app_user --format json
```

### Rotate secrets

`rotate` rewraps secrets with a new vault password when run without a name.
When run with a secret name, it rotates only that secret.

```bash
dew vault rotate
dew vault rotate --name DB_PASSWORD
dew vault rotate --name DB_PASSWORD --format json
```

### Delete a secret

```bash
dew vault delete --name DB_PASSWORD
dew vault delete --name DB_PASSWORD --format json
```

### Metadata format for rotation-aware secrets

Attach arbitrary metadata and include rotation policy details. Example shape:

```json
{
  "rotation": {
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
2. Attach `rotation.generator` and generator args to secret metadata.
3. Run `dew vault rotate --name ...` to rotate one secret, or `dew vault rotate`
   to rotate all secrets.
