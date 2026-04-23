# Dew Kanban Board

The Dew Kanban Board lets you create and manage tickets across a set of configurable columns. Every command is also registered as an MCP tool, so AI agents can interact with the board using the same operations as the CLI.

## Storage layout

Tickets live inside the `.project/kanban/` directory. Each column has its own subdirectory, and attachments are stored separately by ticket ID so they survive column moves:

```text
.project/
└── kanban/
    ├── backlog/
    │   └── DEW-0001.md
    ├── doing/
    │   └── DEW-0002.md
    ├── done/
    │   └── DEW-0003.md
    ├── archive/            ← soft-deleted tickets (future)
    └── attachments/
        └── DEW-0001/       ← per-ticket attachment directory
            └── screenshot.png
```

## Ticket format

Each ticket is a Markdown file with a YAML frontmatter block. The column is derived from the containing directory and is not stored redundantly in the file.

```markdown
---
id: DEW-0001
title: "My ticket"
type: story
created: 2026-04-23T19:00:00.000Z
links:
  - id: DEW-0002
    type: blocks
---

Body text goes here.

---

First comment.

---

Second comment.
```

## CLI commands

All commands are available under `dew kanban <subcommand>`.

| Subcommand | Description                                                     |
| ---------- | --------------------------------------------------------------- |
| `create`   | Create a new ticket (`--title`, `--type`, `--column`, `--body`) |
| `list`     | List tickets (`--column`, `--type`)                             |
| `get`      | Get a ticket by ID (`--id`)                                     |
| `update`   | Update fields on a ticket (`--id`, `--title`, `--type`, `--column`, `--body`) |
| `delete`   | Delete a ticket permanently (`--id`)                            |
| `move`     | Move a ticket to a different column (`--id`, `--column`)        |
| `search`   | Full-text search across all ticket content (`--query`)          |
| `comment`  | Append a comment to a ticket (`--id`, `--comment`)              |
| `config`   | Print the current kanban configuration                          |
| `stats`    | Show ticket counts by column and type                           |
| `link`     | Link two tickets with a typed relationship (`--id`, `--target`, `--type`) |
| `unlink`   | Remove a link between two tickets (`--id`, `--target`)          |

## Ticket links

Links are typed and bidirectional — writing one side automatically writes the inverse on the target.

| Type              | Inverse            | Use case                          |
| ----------------- | ------------------ | --------------------------------- |
| `blocks`          | `is_blocked_by`    | Dependency between tickets        |
| `relates_to`      | `relates_to`       | General relationship (symmetric)  |
| `duplicates`      | `is_duplicated_by` | Duplicate ticket tracking         |
| `parent_of`       | `child_of`         | Epic → story → task hierarchy     |

## Configuration

Columns, ticket types, and the ticket ID prefix are configured in `.project/dew.yaml`:

```yaml
dew:
  kanban:
    prefix: "DEW"
    ticket_types:
      - id: epic
        name: Epic
      - id: story
        name: Story
    columns:
      - id: backlog
        name: Backlog
        color: blue
      - id: doing
        name: Doing
        color: yellow
      - id: done
        name: Done
        color: green
```

See the [Configuration documentation](../config.md) for the full schema reference.
