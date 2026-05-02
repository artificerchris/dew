# Dew Configuration

Dew is configured via a `dew.yaml` file stored in the `.project/` directory at the root of your project. Running `dew init .` will generate this file with sensible defaults.

## File Location

```text
your-project/
└── .project/
    └── dew.yaml
```

## Full Schema

```yaml
dew:
  kanban:
    prefix: "PROJ"      # Short prefix used for ticket IDs (e.g. PROJ-42)

    ticket_types:       # The types of tickets your board supports
      - id: "epic"
        name: "Epic"
      - id: "story"
        name: "Story"
      - id: "task"
        name: "Task"
      - id: "bug"
        name: "Bug"
      - id: "spike"
        name: "Spike"

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

The MCP server currently has no project-level `dew.yaml` configuration. Configure
your MCP client to run `dew mcp serve`; see the [MCP documentation](./features/mcp.md).

### `dew.kanban`

| Field          | Type   | Description                                                                                                  |
| -------------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| `prefix`       | string | Short uppercase prefix prepended to ticket IDs (e.g. `PROJ-1`).                                              |
| `ticket_types` | list   | The ticket types available on the board. Each entry requires an `id` and a `name`.                           |
| `columns`      | list   | The columns on the board, in order from left to right. Each entry requires an `id`, a `name`, and a `color`. |

#### Column colors

The following named colors are supported for column display:

`red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `grey`
