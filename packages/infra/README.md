# dew_infra

Infrastructure service management for the Dew CLI.

`dew_infra` discovers service manifests under `.project/infrastructure`,
validates referenced Quadlet files and JSON Schemas, and manages Podman
Quadlets through systemd. It is designed around a runtime boundary so Dew can
support additional container runtimes in later releases.

Most users should install the `dew` CLI package instead:

```sh
dart pub global activate dew
```

See the main Dew documentation for the `dew infra` command reference:

<https://github.com/artificerchris/dew#readme>

## License

MIT — see [LICENSE](LICENSE).
