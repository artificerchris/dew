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

| Subcommand  | Description                                                                         |
| ----------- | ----------------------------------------------------------------------------------- |
| `create`    | Create a new ticket (`--title`, `--type`, `--column`, `--body`)                     |
| `list`      | List tickets (`--column`, `--type`, `--label`, `--milestone`, `--include-archived`) |
| `get`       | Get a ticket by ID (`--id`)                                                         |
| `update`    | Update fields on a ticket (`--id`, `--title`, `--type`, `--column`, `--body`)       |
| `delete`    | Delete a ticket permanently (`--id`)                                                |
| `move`      | Move a ticket to a different column (`--id`, `--column`)                            |
| `search`    | Full-text search across all ticket content (`--query`, `--include-archived`)        |
| `comment`   | Append a comment to a ticket (`--id`, `--comment`)                                  |
| `archive`   | Soft-delete a ticket by moving it to the archive column (`--id`)                    |
| `unarchive` | Restore an archived ticket to a column (`--id`, `--column`)                         |
| `link`      | Link two tickets with a typed relationship (`--id`, `--target`, `--type`)           |
| `unlink`    | Remove a link between two tickets (`--id`, `--target`)                              |
| `stats`     | Show ticket counts by column and type                                               |
| `board`     | Print an ASCII representation of the board                                          |
| `config`    | Print the current kanban configuration                                              |
| `tui`       | Launch the interactive terminal UI                                                  |

## Ticket links

Links are typed and bidirectional — writing one side automatically writes the inverse on the target.

| Type         | Inverse            | Use case                         |
| ------------ | ------------------ | -------------------------------- |
| `blocks`     | `is_blocked_by`    | Dependency between tickets       |
| `relates_to` | `relates_to`       | General relationship (symmetric) |
| `duplicates` | `is_duplicated_by` | Duplicate ticket tracking        |
| `parent_of`  | `child_of`         | Epic → story → task hierarchy    |

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

## Interactive TUI

Launch the interactive terminal board with:

```bash
dew kanban tui
```

The TUI has three modes. Press **F1** in any mode for a context-sensitive help overlay.

### Modes

| Mode       | How to enter                       | How to leave             |
| ---------- | ---------------------------------- | ------------------------ |
| **Board**  | Default on launch                  | `q` to quit              |
| **Detail** | Press `Enter` on a ticket in Board | `b` or `Esc`             |
| **Editor** | Press `e` in Board or Detail mode  | `s` save / `Esc` discard |

### Keybinding reference

#### Board mode

| Key       | Action                                                 |
| --------- | ------------------------------------------------------ |
| `↑` / `↓` | Navigate tickets within the current column             |
| `←` / `→` | Switch to the previous / next column                   |
| `<` / `>` | Move the selected ticket to the previous / next column |
| `Enter`   | Open Detail view for the selected ticket               |
| `n`       | Create a new ticket (opens Editor)                     |
| `e`       | Edit the selected ticket (opens Editor)                |
| `a`       | Archive the selected ticket                            |
| `D`       | Delete the selected ticket (with confirmation)         |
| `c`       | Append a comment to the selected ticket                |
| `L`       | Link the selected ticket to another ticket             |
| `?`       | Open the live filter / search overlay                  |
| `F1`      | Toggle the help overlay                                |
| `q`       | Quit                                                   |

#### Detail mode

| Key         | Action                         |
| ----------- | ------------------------------ |
| `↑` / `↓`   | Scroll the ticket content      |
| `e`         | Edit the ticket (opens Editor) |
| `b` / `Esc` | Return to Board mode           |
| `F1`        | Toggle the help overlay        |
| `q`         | Quit                           |

#### Editor mode

| Key       | Action                                                                   |
| --------- | ------------------------------------------------------------------------ |
| `↑` / `↓` | Move between fields                                                      |
| `←` / `→` | Cycle through selector values (type, column)                             |
| `Enter`   | Edit the focused text field inline, or open `$VISUAL`/`$EDITOR` for body |
| `d`       | Delete the current item (e.g. remove a label)                            |
| `s`       | Save changes and return to the previous mode                             |
| `Esc`     | Discard changes and return to the previous mode                          |
| `F1`      | Toggle the help overlay                                                  |

> **Body editing:** pressing `Enter` on the body field suspends the TUI and opens
> `$VISUAL` or `$EDITOR` (falling back to `vi`) so you can write long-form content
> in your preferred editor. The TUI resumes once you save and exit.

### Auto-refresh

The board watches the `.project/kanban/` directory for file-system events and
reloads automatically when ticket files are created, modified, or deleted — so
the view stays live whether changes come from another terminal session, a
`git pull`, or an AI agent running `dew mcp serve`.
