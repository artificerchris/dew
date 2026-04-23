import 'package:dew_core/dew_core.dart';

/// Collects [McpToolProvider] instances and exposes their combined tool list.
class McpToolRegistry {
  final List<McpToolProvider> _providers = [];

  /// Adds [provider] to the registry.
  void register(McpToolProvider provider) => _providers.add(provider);

  /// All tools from every registered provider, in registration order.
  List<McpTool> get allTools =>
      List.unmodifiable(_providers.expand((p) => p.tools));
}
