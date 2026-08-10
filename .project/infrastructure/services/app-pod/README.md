# App Pod

Sample local pod service managed by `dew infra` and Podman Quadlets.

```bash
dew infra validate app-pod
dew infra up app-pod
dew infra status app-pod
dew infra logs app-pod --lines 100
```

This sample shows a Podman pod with a web container and a sidecar container.

- web endpoint: `http://127.0.0.1:8088`
- pod: `dew_app-pod`
- web container: `dew_app-pod-web`
- sidecar container: `dew_app-pod-sidecar`

Stop it with:

```bash
dew infra down app-pod
```
