# PostgreSQL 18

Sample local PostgreSQL 18 service managed by `dew infra` and Podman Quadlets.

```bash
dew infra validate postgresql-18
dew infra up postgresql-18
dew infra status postgresql-18
dew infra logs postgresql-18 --lines 100
```

The sample binds PostgreSQL to `127.0.0.1:5432` with:

- database: `dew`
- user: `dew`
- password: `dew_dev_password`
- data volume: `dew_postgresql_18_data`

Stop it with:

```bash
dew infra down postgresql-18
```

The named volume is intentionally retained after stopping the service.
