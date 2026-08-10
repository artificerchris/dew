# Dew Configuration

Dew is configured via a `dew.yaml` file stored in the `.project/` directory at the root of your project. Running `dew init .` will generate this file with sensible defaults.

For scaffold template layering and `dew init` flags, see
[Init and Scaffolds](./features/init.md).

## File Location

```text
your-project/
└── .project/
    └── dew.yaml
```

Path-like values in `dew.yaml` are resolved relative to `.project/dew.yaml`
unless they are absolute (for example, paths under `dew.vault`).

Infrastructure services are not configured in `dew.yaml`; they are discovered
from `.project/infrastructure/services/*/manifest.yaml`.

## Full Schema

```yaml
dew:
  mcp:
    host: "localhost"   # Hostname the MCP server binds to
    port: 8080          # Port the MCP server listens on

  kanban:
    prefix: "PROJ"      # Short prefix used for ticket IDs (e.g. PROJ-42)

    ticket_types:       # The types of tickets your board supports
      - id: "epic"
        name: "Epic"
        color: "magenta"  # Optional — badge color in the TUI
      - id: "story"
        name: "Story"
        color: "cyan"
      - id: "task"
        name: "Task"
        color: "blue"
      - id: "bug"
        name: "Bug"
        color: "red"
      - id: "spike"
        name: "Spike"
        color: "yellow"

    columns:            # Ordered list of columns on your Kanban board
      - id: "backlog"
        name: "Backlog"
        color: "blue"
      - id: "doing"
        name: "Doing"
        color: "yellow"
      - id: "done"
        name: "Done"
        color: "green"
```

## Reference

### `dew.mcp`

| Field  | Type    | Default       | Description                       |
| ------ | ------- | ------------- | --------------------------------- |
| `host` | string  | `"localhost"` | Hostname the MCP server binds to. |
| `port` | integer | `8080`        | Port the MCP server listens on.   |

### `dew.kanban`

| Field          | Type   | Description                                                                                                  |
| -------------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| `prefix`       | string | Short uppercase prefix prepended to ticket IDs (e.g. `PROJ-1`).                                              |
| `ticket_types` | list   | The ticket types available on the board. Each entry requires an `id` and a `name`, and may set a `color`.    |
| `columns`      | list   | The columns on the board, in order from left to right. Each entry requires an `id`, a `name`, and a `color`. |

#### Colors

The same named colors apply to the `color` on a column and on a ticket type:

`red`, `green`, `yellow`, `blue`, `magenta` (alias `purple`), `cyan` (alias
`teal`), `white`

Each also has a bright variant, written either camelCase or snake_case:
`brightRed` / `bright_red`, `brightGreen` / `bright_green`, and likewise for
`bright_yellow`, `bright_blue`, `bright_magenta`, `bright_cyan`,
`bright_white`.

Names are matched case-insensitively. An unrecognised color falls back to
`cyan`, so a typo shows up as a wrong color rather than an error.

`color` is optional on a ticket type. When omitted, the TUI falls back to a
built-in palette keyed by the type's `id` (`bug` red, `task` blue,
`feature`/`feat` green, `chore`/`spike` yellow, `epic` magenta, `story` cyan),
and any other type renders white.
