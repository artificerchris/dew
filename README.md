# Dew Project Management Tool

Dew is a project management tool built in Dart, designed to help developers organize and manage their projects efficiently. It provides a simple command-line interface for creating, managing, and tracking projects, tasks, and deadlines.

## Features

### MCP Server

Dew includes an MCP server for AI agents to interact with your project. This allows you to integrate AI capabilities into your project management workflow, enabling features like automated task creation, progress tracking, and more. Read more about the MCP server in the [Dew MCP Feature Documentation](./docs/features/mcp.md).

### Kanban Board

Dew includes a Kanban board feature that allows you to visualize your tasks and their progress. You can create columns for different stages of your workflow (e.g., To Do, In Progress, Done) and move tasks between them as you work on them. Read more about the Kanban board in the [Dew Kanban Feature Documentation](./docs/features/kanban.md).

## Configuration

Dew's configuration is managed with the [dew.yaml](.project/dew.yaml) file, which allows you to customize various aspects of the tool to fit your workflow. You can specify project settings, task templates, and other preferences in this file. Read more about configuring Dew in the [Dew Configuration Documentation](./docs/config.md).

## Getting Started

To get started with Dew, follow these steps:

```bash
# Activate the Dew CLI
dart pub global activate dew
```

Once you have the CLI installed, you can create a new project with:

```bash
dew init .
```

This will set up the necessary files and directories for your project. You can then start adding tasks and managing your project using the Dew CLI.

For more detailed instructions and documentation, please refer to the [Dew Documentation](./docs/index.md).
