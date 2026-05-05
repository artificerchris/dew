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
        ├── metadata.toml
        ├── app_postgres.container
        ├── app_postgres.container.d/
        ├── app_postgres.profiles.d/
        ├── configure.schema.json
        ├── init.schema.json
        └── config/
```

## Manifest

```toml
[service]
id = "postgres"
name = "PostgreSQL"
unit = "app_postgres.service"
container_name = "app_postgres"

[runtime]
type = "podman-quadlet"

[container]
file = "app_postgres.container"
dropins_dir = "app_postgres.container.d"
profiles_dir = "app_postgres.profiles.d"

[schemas]
configure = "configure.schema.json"
init = "init.schema.json"
```

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
unit.
