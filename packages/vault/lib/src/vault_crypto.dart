import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class VaultCrypto {
  static const int defaultIterations = 200000;
  static const int defaultKeyLength = 32;
  static const int defaultSaltLength = 16;
  static const int defaultNonceLength = 12;
  static const int defaultVersion = 1;
  static const int gcmMacLength = 128;

  static Map<String, dynamic> encryptToEnvelope(
    String value, {
    required String password,
    int iterations = defaultIterations,
  }) {
    final plainBytes = utf8.encode(value);
    final salt = _randomBytes(defaultSaltLength);
    final nonce = _randomBytes(defaultNonceLength);
    final key = _deriveKey(password: password, salt: salt, iterations: iterations);

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      gcmMacLength,
      nonce,
      Uint8List(0),
    );
    cipher.init(true, params);

    final encrypted = cipher.process(Uint8List.fromList(plainBytes));
    return {
      'version': defaultVersion,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(encrypted),
    };
  }

  static String decryptFromEnvelope(
    Map<String, dynamic> payload, {
    required String password,
  }) {
    final version = _asInt(payload['version'], fallback: defaultVersion);
    if (version != defaultVersion) {
      throw ArgumentError('Unsupported vault payload format: $version');
    }

    final kdf = _asMap(payload['kdf']);
    final iterations = _asInt(kdf['iterations'], fallback: defaultIterations);
    final salt = _decodeBytes(kdf['salt'], field: 'salt');
    final nonce = _decodeBytes(payload['nonce'], field: 'nonce');
    final ciphertext = _decodeBytes(payload['ciphertext'], field: 'ciphertext');

    final key = _deriveKey(
      password: password,
      salt: salt,
      iterations: iterations,
    );

    try {
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        gcmMacLength,
        nonce,
        Uint8List(0),
      );
      cipher.init(false, params);
      final plaintext = cipher.process(ciphertext);
      return utf8.decode(plaintext);
    } catch (error) {
      throw ArgumentError('Unable to decrypt secret value. $error');
    }
  }

  static String randomPassword({int length = 64}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{};:,.?/|';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Uint8List _deriveKey({
    required String password,
    required Uint8List salt,
    required int iterations,
  }) {
    final params = Pbkdf2Parameters(salt, iterations, defaultKeyLength);
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static Uint8List _decodeBytes(dynamic value, {required String field}) {
    if (value is! String) {
      throw ArgumentError('Invalid vault payload field "$field".');
    }
    return Uint8List.fromList(base64Decode(value));
  }
}
