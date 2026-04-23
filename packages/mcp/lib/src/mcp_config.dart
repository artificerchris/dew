import 'package:dew_core/dew_core.dart';
import 'package:yaml/yaml.dart';

class McpConfig {
  final String host;
  final int port;

  const McpConfig({required this.host, required this.port});
}

extension McpDewConfig on DewConfig {
  McpConfig get mcp {
    final mcpYaml = (raw['dew'] as YamlMap)['mcp'] as YamlMap;
    return McpConfig(
      host: mcpYaml['host'] as String,
      port: mcpYaml['port'] as int,
    );
  }
}
