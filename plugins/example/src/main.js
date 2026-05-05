function run(context, args) {
  return {
    plugin: context.playbook,
    message: 'Example plugin executed',
    projectRoot: context.project_root,
    pluginDirectory: context.plugin_directory,
    args,
  };
}
