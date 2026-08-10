# Dew Infrastructure Samples

This directory contains sample services that exercise `dew infra` using the same
layout a project would use for local infrastructure.

Each service lives under `services/<service-id>/` and is discovered from its
`manifest.yaml`.

Included samples:

- `postgresql-18`: single PostgreSQL container with a named data volume.
- `valkey-9`: cache container backed by a Quadlet volume.
- `rustfs`: S3-compatible object storage on a Quadlet network and volume.
- `keycloak`: multi-container service with PostgreSQL on a shared network.
- `app-pod`: Podman pod with web and sidecar containers.
- `local-api-build`: local image build consumed by a container Quadlet.
