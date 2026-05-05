# Dew Runner

The runner feature lets you execute JavaScript playbooks from your Dew workspace with
the `dew run` command.

Playbooks are JavaScript files loaded from a configurable plugin directory and
executed through the embedded `quickjs` engine.

## Configuration

Runner settings are under `dew.plugins` in `dew.yaml`:

```yaml
dew:
  plugins:
    directory: ~/.config/dew/plugins
```

If omitted, the default is `${XDG_CONFIG_HOME}/dew/plugins` (or `~/.config/dew/plugins`).

## Command

### `dew run <playbook> [args...]`

- If `<playbook>` is a JS file path, it is executed directly.
  - Example: `dew run ./plugins/example/src/main.js`.
- Otherwise, `<playbook>` is treated as a plugin name inside the plugins directory.
  - `deploy` resolves to `<plugins directory>/deploy/dew.yaml` and executes its `entrypoint`.
  - `deploy.js` is treated as a direct JS path unless no such file is found.
- Extra tokens after `<playbook>` are passed to the JS context as `args`.

### `dew plugins list`

Lists all discovered JavaScript playbooks in `dew.plugins.directory`.

```bash
dew plugins list
```

## Playbook contract

A playbook must expose one of the following entry points:

- `run(context, args)`
- `main(context, args)`
- `execute(context, args)`

The `context` object includes:

```json
{
  "playbook": "deploy",
  "project_root": "/path/to/project",
  "plugin_directory": "/path/to/plugins"
}
```

### Example

```js
function run(context, args) {
  const target = args[0] ?? "default";
  return {
    ok: true,
    playbook: context.playbook,
    target,
  };
}
```

`dew run deploy production`
returns:

```json
{
  "ok": true,
  "playbook": "deploy",
  "target": "production"
}
```
