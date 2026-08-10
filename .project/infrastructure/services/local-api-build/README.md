# Local API Build

Sample local image build managed by `dew infra` and Podman Quadlets.

```bash
dew infra validate local-api-build
dew infra up local-api-build
dew infra status local-api-build
dew infra logs local-api-build --lines 100
```

This sample shows a `.build` Quadlet that builds a local image from
`Containerfile`, then runs it through a `.container` Quadlet.

- endpoint: `http://127.0.0.1:8090`
- built image: `localhost/dew_local-api-build:latest`
- container: `dew_local-api-build`

Stop it with:

```bash
dew infra down local-api-build
```
