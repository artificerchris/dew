# Infrastructure

`dew infra` manages project-local infrastructure services declared under
`.project/infrastructure`.

The initial runtime backend is Podman Quadlets installed into systemd search
paths. The command surface is runtime-oriented rather than Podman-specific so
future backends can be added without changing project manifests or common CLI
workflows.

## Layout

```text
.project/infrastructure/
└── services/
    └── postgres/
        ├── manifest.yaml
        ├── app_postgres.container
        ├── app_postgres.container.d/
        ├── app_postgres.profiles.d/
        ├── schemas/
        │   ├── configure.schema.json
        │   └── init.schema.json
        └── config/
```

## Manifest

```yaml
id: postgres
name: PostgreSQL

runtime:
  type: podman-quadlet

quadlets:
  - file: app_postgres.container
    unit: app_postgres.service
    container_name: app_postgres
    dropins_dir: app_postgres.container.d
    profiles_dir: app_postgres.profiles.d

schemas:
  configure: schemas/configure.schema.json
  init: schemas/init.schema.json
```

The `quadlets` list can contain any supported Podman Quadlet source type:
`.artifact`, `.build`, `.container`, `.image`, `.kube`, `.network`, `.pod`, and
`.volume`. If `unit` is omitted, Dew derives the default generated systemd unit
from the Quadlet filename. Declare `unit` when the Quadlet file uses a
`ServiceName=` override.

The package-level schema for this file is
`packages/infra/schemas/service-manifest.schema.json`.

## Commands

```bash
dew infra list
dew infra show postgres
dew infra validate --all
dew infra configure postgres schema
dew infra configure postgres show
dew infra configure postgres apply --file config.json --set port=5432
dew infra init postgres schema
dew infra init postgres run --file init.json
dew infra install postgres
dew infra up postgres
dew infra status postgres
dew infra logs postgres --lines 200
dew infra down postgres
dew infra delete postgres --container
```

Use `--dry-run` on mutating commands to print filesystem, systemctl, journalctl,
and podman actions without applying them. Use `--scope user` for the default
user systemd path or `--scope system` for `/etc/containers/systemd`.

`dew infra up` installs missing Quadlet files, reloads systemd, then starts the
declared units.

## Samples

The Dew repository includes sample service bringups under
`.project/infrastructure/services/`.

`postgresql-18` brings up a local PostgreSQL 18 container through Podman
Quadlets:

```bash
dew infra validate postgresql-18
dew infra up postgresql-18
```
