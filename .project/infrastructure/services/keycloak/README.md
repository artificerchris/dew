# Keycloak

Sample local Keycloak service managed by `dew infra` and Podman Quadlets.

```bash
dew infra validate keycloak
dew infra up keycloak
dew infra status keycloak
dew infra logs keycloak --lines 100
```

This sample shows a multi-container service with an explicit Quadlet network and
a PostgreSQL dependency.

- Keycloak: `http://127.0.0.1:8080`
- admin user: `admin`
- admin password: `admin`
- database: `keycloak`
- database container: `dew_keycloak-postgresql`
- database volume: `dew_keycloak_postgresql_data`

Stop it with:

```bash
dew infra down keycloak
```

The PostgreSQL volume is intentionally retained after stopping the service.
