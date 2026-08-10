# Dew Agent Guidance

This document provides guidelines and rules for agents contributing to the
Dew project. It outlines the expected behavior, coding standards, and
collaboration practices to ensure a productive and respectful environment for
all contributors.

## General Guidelines

- The references directory should be used for storing external resources,
  temporary files, and other things the agent needs that aren't part of the
  actual project. This can include things like documentation, clones of other
  repositories, screenshots, and other resources that may be helpful for
  development but are not part of the final codebase.
- Avoid duplicating existing code or functionality. The footprint of the
  operating system should be as small as possible while still remaining
  readable and maintainable. Generally this means all features should be
  implemented as though they will be used by other features, and that code
  should be reused where possible.
- All code should be well-documented, with clear comments explaining the
  purpose and functionality of each component. This is especially important for
  security-related features, where clarity can help prevent vulnerabilities.
- Use language-appropriate API documentation comments for public modules,
  types, and functions (for example Rustdoc in Rust and doc comments in Dart).
- Follow each language and framework's idiomatic conventions and best practices
  to ensure consistency and readability across the codebase.
- Prefer strong, explicit types (for example enums/sealed types) over ad-hoc
  constants when modeling related sets of values.
- Use pattern matching and type-system features where available to handle
  different cases clearly and safely.
- Constants are acceptable for defining fixed values that are not part of a
  related set, such as configuration parameters or hardware addresses, but
  should be used judiciously to avoid cluttering the codebase with unnecessary
  constants.

## Project Management

- Every task should be clearly defined and documented in the
  `.project/kanban/` board and managed through Dew.
- Ticket lifecycle operations (create, list, move, update, comment, archive,
  links) should be performed through the Dew MCP tools when available.
- Do not manage ticket state by hand-editing board files unless doing one-off
  migration, import, or recovery work.
- If a task is not documented, create a new ticket in Dew before starting work
  so progress is tracked and visible.
- Where possible, `TODO` comments should reference a ticket by including the
  ticket's unique identifier in the comment. This helps maintain a clear
  connection between the code and the project management system, making it
  easier to track progress and understand the context of each task.
- The `.project/kanban/{backlog,doing,done,archive}/` directories are the
  board columns. Tickets in progress belong in `doing`, and completed work is
  moved to `done`.
- Ticket filenames are `<PREFIX>-NNNN.md` and must match the ticket `id` in
  frontmatter.
- Frontmatter should contain the following fields:
  - `id`: A unique identifier for the task.
  - `title`: A brief title summarizing the task.
  - `type`: Ticket type identifier (for example `epic`, `story`, `task`,
    `bug`, or `spike`).
  - `created`: RFC3339 timestamp for ticket creation.
- After the front matter comes the markdown content, which should provide a
  detailed description of the task, including any relevant information,
  requirements, or context needed for completion.
- Do not include a `column` field in frontmatter; the column is determined by
  the ticket file's directory.
- Comments may be stored in the ticket by appending them to the end of the
  markdown content, separated from the description and other comments by a
  horizontal rules (`---`) for clarity. Each comment should include the
  author's name, and the content of the comment.
- Tickets that need attachments should have a directory created in
  `.project/kanban/attachments/` with the same name as the ticket file (without
  the `.md` extension), and the attachment should be stored in that directory.
  The attachment can then be referenced in the markdown content of the ticket
  using a relative path.

## Tooling and Commands

- This repository uses a root `justfile` for common development workflows. Run
  `just --list` to see the available recipes.
- Respect the root `.editorconfig` for cross-editor whitespace and line-ending
  behavior.
- Treat any analyzer/linter finding (`info`, `warning`, or `error`) as a
  blocking issue: fix it before merging unless it is objectively impossible.
  If a finding must remain, ask for explicit approval first and gate the exception
  with a `TODO` comment that explains why the issue is intentionally deferred.
- Use `melos run format` to format Dart packages in the workspace.
- Use `melos run fix` to apply automatic fixes from Dart static analysis.
- Use `melos run analyze` to run Dart static analysis.
- Use `melos run test` to run Dart tests across workspace packages.
- Use `markdownlint-cli2 .` to check for markdown style issues in documentation
  files so the repo's configured ignores are applied.
