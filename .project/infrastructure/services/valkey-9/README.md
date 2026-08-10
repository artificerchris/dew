# Valkey 9

Sample local Valkey service managed by `dew infra` and Podman Quadlets.

```bash
dew infra validate valkey-9
dew infra up valkey-9
dew infra status valkey-9
dew infra logs valkey-9 --lines 100
```

This sample shows a container backed by a named Quadlet volume.

- host port: `127.0.0.1:6379`
- container: `dew_valkey-9`
- data volume: `dew_valkey-9_data`

Stop it with:

```bash
dew infra down valkey-9
```

The named volume is intentionally retained after stopping the service.
