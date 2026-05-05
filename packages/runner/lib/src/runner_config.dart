import 'dart:io';

import 'package:dew_core/dew_core.dart';
import 'package:path/path.dart' as p;

class RunnerConfig {
  final String pluginDirectory;

  const RunnerConfig({required this.pluginDirectory});
}

/// Plugin-related Dew config.
extension RunnerDewConfig on DewConfig {
  RunnerConfig get runner => RunnerConfig(
    pluginDirectory: _resolvePluginDirectory(
      raw: raw,
      fallback: defaultPluginDirectory(),
    ),
  );
}

const String _pluginsKey = 'plugins';
const String _directoryKey = 'directory';

/// Default plugin directory following XDG config location semantics.
String defaultPluginDirectory() {
  final xdgConfigHome = Platform.environment['XDG_CONFIG_HOME'];
  if (xdgConfigHome != null && xdgConfigHome.isNotEmpty) {
    return p.join(xdgConfigHome, 'dew', 'plugins');
  }

  final home = _homeDirectory();
  return home.isNotEmpty ? p.join(home, '.config', 'dew', 'plugins') : '.config/dew/plugins';
}

String _resolvePluginDirectory({required dynamic raw, required String fallback}) {
  final dewSection = _coerceMap(raw['dew']);
  final pluginsSection = _coerceMap(dewSection[_pluginsKey]);

  return _normalizePath(
    _asString(pluginsSection[_directoryKey], fallback: fallback),
  );
}

String _normalizePath(String input) {
  final expanded = _expandTilde(input);
  return p.normalize(expanded);
}

String _expandTilde(String input) {
  if (!input.startsWith('~')) return input;
  final home = _homeDirectory();
  if (home.isEmpty) return input;
  if (input.length == 1) return home;
  final rest = input.substring(1);
  return p.join(home, rest.startsWith('/') ? rest.substring(1) : rest);
}

String _homeDirectory() {
  return Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';
}

Map<String, dynamic> _coerceMap(dynamic input) {
  if (input == null) return {};
  if (input is Map) {
    return input.map(
      (key, value) => MapEntry(key.toString(), _coerceValue(value)),
    );
  }
  return {};
}

dynamic _coerceValue(dynamic value) {
  if (value is Map) return _coerceMap(value);
  if (value is List) return value.map(_coerceValue).toList();
  return value;
}

String _asString(dynamic value, {required String fallback}) {
  if (value == null) return fallback;
  return value.toString();
}
