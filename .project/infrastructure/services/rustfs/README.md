# RustFS

Sample local RustFS object storage service managed by `dew infra` and Podman
Quadlets.

```bash
dew infra validate rustfs
dew infra up rustfs
dew infra status rustfs
dew infra logs rustfs --lines 100
```

This sample shows a container on an explicit Quadlet network with a named
Quadlet volume.

- S3 API: `http://127.0.0.1:9000`
- console: `http://127.0.0.1:9001`
- user: `rustfsadmin`
- password: `rustfsadmin`
- data volume: `dew_rustfs_data`

Stop it with:

```bash
dew infra down rustfs
```

The named volume is intentionally retained after stopping the service.
