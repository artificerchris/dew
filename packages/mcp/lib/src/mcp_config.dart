import 'package:dew_core/dew_core.dart';

class McpConfig {
  McpConfig();
}

extension McpDewConfig on DewConfig {
  McpConfig get mcp {
    return McpConfig();
  }
}
