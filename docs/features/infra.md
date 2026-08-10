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

Use `files` for non-Quadlet assets that must be installed beside the Quadlet
files, such as a `Containerfile` used by a `.build` unit.

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

Available samples:

- `postgresql-18`: single PostgreSQL 18 container with a named data volume.
- `valkey-9`: cache container backed by a Quadlet volume.
- `rustfs`: S3-compatible object storage on a Quadlet network and volume.
- `keycloak`: multi-container Keycloak and PostgreSQL service on a shared
  network.
- `app-pod`: Podman pod with web and sidecar containers.
- `local-api-build`: local image build consumed by a container Quadlet.

```bash
dew infra validate postgresql-18
dew infra up postgresql-18
```
