import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'vault_config.dart';

class VaultGenerators {
  static const _passwordCharsetLower = 'abcdefghijklmnopqrstuvwxyz';
  static const _passwordCharsetUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _passwordCharsetDigits = '0123456789';
  static const _passwordCharsetSymbols = '!@#\$%^&*()-_=+[]{};:,.?/|';

  static String generate(String type, Map<String, dynamic> options) {
    return switch (type) {
      'random_password' => randomPassword(options),
      'random_token' => randomToken(options),
      'uuid_v4' => uuidV4(options),
      _ => throw ArgumentError('Unknown generator type "$type".'),
    };
  }

  static String generateByName({
    required String nameOrType,
    required Map<String, VaultGeneratorDefinition> generators,
    Map<String, dynamic>? options,
  }) {
    final configured = generators[nameOrType];
    if (configured != null) {
      final merged = Map<String, dynamic>.from(configured.config);
      if (options != null) {
        for (final entry in options.entries) {
          merged[entry.key] = entry.value;
        }
      }
      return generate(configured.type, merged);
    }

    return generate(nameOrType, options ?? const {});
  }

  static String randomPassword(Map<String, dynamic> options) {
    final length = _readIntOption(options['length'], fallback: 32);
    final includeLower = _readBoolOption(options['include_lowercase'], fallback: true);
    final includeUpper = _readBoolOption(options['include_uppercase'], fallback: true);
    final includeNumbers = _readBoolOption(options['include_numbers'], fallback: true);
    final includeSymbols = _readBoolOption(options['include_symbols'], fallback: false);

    final chars = StringBuffer();
    if (includeLower) {
      chars.write(_passwordCharsetLower);
    }
    if (includeUpper) {
      chars.write(_passwordCharsetUpper);
    }
    if (includeNumbers) {
      chars.write(_passwordCharsetDigits);
    }
    if (includeSymbols) {
      chars.write(_passwordCharsetSymbols);
    }

    if (chars.isEmpty) {
      throw ArgumentError('Generator requires at least one enabled character set.');
    }
    final charset = chars.toString();
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String randomToken(Map<String, dynamic> options) {
    final bytes = _readIntOption(options['bytes'], fallback: 32);
    final encoding = _readStringOption(
      options['encoding'],
      fallback: 'base64',
    ).toLowerCase();
    final randomBytes = _randomBytes(bytes);

    switch (encoding) {
      case 'base64':
        return base64.encode(randomBytes);
      case 'base64url':
      case 'url':
      case 'urlsafe':
      case 'url-safe':
        return base64Url.encode(randomBytes).replaceAll('=', '');
      case 'hex':
      case 'hexadecimal':
        return randomBytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
      default:
        throw ArgumentError('Unknown random_token encoding "$encoding".');
    }
  }

  static String uuidV4(Map<String, dynamic> options) {
    final bytes = _randomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final buffer = StringBuffer();
    buffer
      ..write(hex.substring(0, 8))
      ..write('-')
      ..write(hex.substring(8, 12))
      ..write('-')
      ..write(hex.substring(12, 16))
      ..write('-')
      ..write(hex.substring(16, 20))
      ..write('-')
      ..write(hex.substring(20));
    return buffer.toString();
  }

  static int _readIntOption(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _readBoolOption(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  static String _readStringOption(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}
