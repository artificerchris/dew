import 'dart:convert';
import 'dart:io';

import 'package:dew_core/dew_core.dart';
import 'package:dew_vault/dew_vault.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

const _testConfig = '''
dew:
  vault:
    password_file: .project/secrets/dew.vault.password
    storage_dir: .project/vault
    generators:
      postgres_password:
        type: random_password
        description: Generate a PostgreSQL-like password.
        config:
          length: 16
          include_symbols: false
''';

MemoryFileSystem _makeFs() {
  final fs = MemoryFileSystem();
  fs.directory('/.project').createSync(recursive: true);
  fs.file('/.project/dew.yaml').writeAsStringSync(_testConfig);
  return fs;
}

Map<String, McpTool> _mcpToolsForFs(MemoryFileSystem fs) {
  final registry = CommandRegistry();
  registerCommands(registry, fs: fs);
  return {for (final tool in registry.mcpTools) tool.name: tool};
}

Map<String, dynamic> _decodeToolJson(String output) {
  return jsonDecode(output) as Map<String, dynamic>;
}

void main() {
  group('registerCommands', () {
    test('registers vault command and MCP tools', () {
      final registry = CommandRegistry();
      final fs = _makeFs();
      registerCommands(registry, fs: fs);

      expect(registry.commands.map((c) => c.name), contains('vault'));
      final tools = registry.mcpTools.map((t) => t.name).toSet();
      expect(
        tools,
        containsAll({
          'vault_init',
          'vault_set_secret',
          'vault_get_secret',
          'vault_update_secret',
          'vault_rename_secret',
          'vault_rotate_secret',
          'vault_generate_secret',
          'vault_list_secrets',
          'vault_delete_secret',
        }),
      );
    });
  });

  group('Vault command tools', () {
    late Map<String, McpTool> tools;
    late MemoryFileSystem fs;

    setUp(() {
      fs = _makeFs();
      tools = _mcpToolsForFs(fs);
      fs.file('/seed.txt').writeAsStringSync('super-secret');
      fs.file('/new-seed.txt').writeAsStringSync('super-secret-v2');
    });

    test('set/get/update/list and delete work end-to-end', () async {
      await tools['vault_set_secret']!.handler({
        'name': 'API_KEY',
        'file': '/seed.txt',
        'metadata':
            '{"rotation":{"generator":"postgres_password","length":12},"notes":"initial"}',
      });

      final listResult = _decodeToolJson(
        await tools['vault_list_secrets']!.handler({'format': 'json'}),
      );
      expect(listResult['count'], 1);
      expect((listResult['secrets'] as List), contains('API_KEY'));

      final before = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'API_KEY',
          'format': 'json',
        }),
      );
      expect(before['value'], 'super-secret');
      expect(before['metadata']['rotation']['generator'], 'postgres_password');

      await tools['vault_update_secret']!.handler({
        'name': 'API_KEY',
        'metadata':
            '{"notes":"rotating","rotation":{"service":"payments","length":20}}',
      });
      final merged = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'API_KEY',
          'format': 'json',
        }),
      );
      expect(merged['metadata']['notes'], 'rotating');
      expect(merged['metadata']['rotation']['service'], 'payments');
      expect(merged['metadata']['rotation']['length'], 20);

      await tools['vault_update_secret']!.handler({
        'name': 'API_KEY',
        'file': '/new-seed.txt',
      });
      final valueUpdated = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'API_KEY',
          'format': 'json',
        }),
      );
      expect(valueUpdated['value'], 'super-secret-v2');

      await tools['vault_delete_secret']!.handler({'name': 'API_KEY'});
      final listAfterDelete = _decodeToolJson(
        await tools['vault_list_secrets']!.handler({'format': 'json'}),
      );
      expect(listAfterDelete['count'], 0);
    });

    test('generate command uses configured generators', () async {
      final generated = _decodeToolJson(
        await tools['vault_generate_secret']!.handler({
          'generator': 'postgres_password',
          'arg': ['length=20', 'include_symbols=false'],
          'format': 'json',
        }),
      );
      expect(generated['generator'], 'postgres_password');
      expect((generated['value'] as String).length, 20);
    });

    test('init command creates directories and password file', () async {
      final initResult = _decodeToolJson(
        await tools['vault_init']!.handler({'format': 'json'}),
      );
      expect(initResult['message'], 'Vault initialised.');
      expect(initResult['initialized'], isTrue);
      expect(
        initResult['password_file'],
        '/.project/secrets/dew.vault.password',
      );
      expect(initResult['storage_dir'], '/.project/vault');

      expect(await fs.directory('/.project/vault').exists(), isTrue);
      expect(
        await fs.file('/.project/secrets/dew.vault.password').exists(),
        isTrue,
      );
    });

    test('init command accepts custom password and storage paths', () async {
      final customInit = _decodeToolJson(
        await tools['vault_init']!.handler({
          'password-file': '.custom/secrets/custom.vault.password',
          'storage-dir': '.custom/vault-store',
          'format': 'json',
        }),
      );
      expect(
        customInit['password_file'],
        '/.project/.custom/secrets/custom.vault.password',
      );
      expect(customInit['storage_dir'], '/.project/.custom/vault-store');
      expect(
        await fs.directory('/.project/.custom/vault-store').exists(),
        isTrue,
      );
      expect(
        await fs
            .file('/.project/.custom/secrets/custom.vault.password')
            .exists(),
        isTrue,
      );
    });

    test('set command accepts metadata from file', () async {
      fs
          .file('/meta.json')
          .writeAsStringSync(
            '{"rotation":{"generator":"postgres_password","length":16},"notes":"from-file"}',
          );
      await tools['vault_set_secret']!.handler({
        'name': 'META_FILE_SECRET',
        'file': '/seed.txt',
        'metadata-file': '/meta.json',
      });

      final loaded = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'META_FILE_SECRET',
          'format': 'json',
        }),
      );
      expect(loaded['metadata']['notes'], 'from-file');
      expect(loaded['metadata']['rotation']['length'], 16);
    });

    test('set command accepts --env source', () async {
      final envValue = Platform.environment['PATH'];
      if (envValue == null || envValue.isEmpty) {
        fail('Expected PATH to be set in test environment.');
      }

      await tools['vault_set_secret']!.handler({
        'name': 'ENV_SECRET',
        'env': 'PATH',
      });
      final loaded = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'ENV_SECRET',
          'format': 'json',
        }),
      );
      expect(loaded['value'], envValue);
    });

    test('update command accepts --env source', () async {
      await tools['vault_set_secret']!.handler({
        'name': 'UPDATABLE_SECRET',
        'file': '/seed.txt',
      });

      final envValue = Platform.environment['HOME'];
      if (envValue == null || envValue.isEmpty) {
        fail('Expected HOME to be set in test environment.');
      }

      await tools['vault_update_secret']!.handler({
        'name': 'UPDATABLE_SECRET',
        'env': 'HOME',
      });
      final loaded = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'UPDATABLE_SECRET',
          'format': 'json',
        }),
      );
      expect(loaded['value'], envValue);
    });

    test('update command accepts metadata file', () async {
      fs
          .file('/meta-update.json')
          .writeAsStringSync(
            '{"rotation":{"generator":"postgres_password","length":24},"notes":"file-metadata"}',
          );
      await tools['vault_set_secret']!.handler({
        'name': 'META_UPDATE_SECRET',
        'file': '/seed.txt',
      });
      await tools['vault_update_secret']!.handler({
        'name': 'META_UPDATE_SECRET',
        'metadata-file': '/meta-update.json',
      });

      final loaded = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'META_UPDATE_SECRET',
          'format': 'json',
        }),
      );
      expect(loaded['metadata']['notes'], 'file-metadata');
      expect(loaded['metadata']['rotation']['length'], 24);
    });

    test('rename command moves secret and metadata', () async {
      await tools['vault_set_secret']!.handler({
        'name': 'LEGACY_KEY',
        'file': '/seed.txt',
        'metadata':
            '{"rotation":{"generator":"postgres_password","length":16},"notes":"legacy"}',
      });

      final renamed = _decodeToolJson(
        await tools['vault_rename_secret']!.handler({
          'from': 'LEGACY_KEY',
          'to': 'CURRENT_KEY',
          'format': 'json',
        }),
      );
      expect(renamed['from'], 'LEGACY_KEY');
      expect(renamed['to'], 'CURRENT_KEY');

      final listResult = _decodeToolJson(
        await tools['vault_list_secrets']!.handler({'format': 'json'}),
      );
      expect(listResult['secrets'], contains('CURRENT_KEY'));
      expect(listResult['secrets'], isNot(contains('LEGACY_KEY')));

      await expectLater(
        tools['vault_get_secret']!.handler({
          'name': 'LEGACY_KEY',
          'format': 'json',
        }),
        throwsA(isA<ArgumentError>()),
      );

      final newSecret = _decodeToolJson(
        await tools['vault_get_secret']!.handler({
          'name': 'CURRENT_KEY',
          'format': 'json',
        }),
      );
      expect(newSecret['metadata']['notes'], 'legacy');
    });

    test('delete command supports json format output', () async {
      await tools['vault_set_secret']!.handler({
        'name': 'TO_DELETE',
        'file': '/seed.txt',
      });
      final deleted = _decodeToolJson(
        await tools['vault_delete_secret']!.handler({
          'name': 'TO_DELETE',
          'format': 'json',
        }),
      );
      expect(deleted, isA<Map<String, dynamic>>());
      await expectLater(
        tools['vault_get_secret']!.handler({'name': 'TO_DELETE'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'rotate command uses rotation metadata and can rotate vault password',
      () async {
        await tools['vault_set_secret']!.handler({
          'name': 'service_db_password',
          'file': '/seed.txt',
          'metadata':
              '{"rotation":{"generator":"postgres_password","length":12}}',
        });
        await tools['vault_set_secret']!.handler({
          'name': 'service_api_key',
          'file': '/new-seed.txt',
          'metadata':
              '{"rotation":{"generator":"postgres_password","length":12}}',
        });

        final before = _decodeToolJson(
          await tools['vault_get_secret']!.handler({
            'name': 'service_db_password',
            'format': 'json',
          }),
        );
        expect(before['value'], 'super-secret');

        final secretRotated = _decodeToolJson(
          await tools['vault_rotate_secret']!.handler({
            'name': 'service_db_password',
            'format': 'json',
          }),
        );
        expect(secretRotated['scope'], 'secret');
        expect(secretRotated['name'], 'service_db_password');

        final after = _decodeToolJson(
          await tools['vault_get_secret']!.handler({
            'name': 'service_db_password',
            'format': 'json',
          }),
        );
        expect(after['value'], isNot('super-secret'));

        final allRotated = _decodeToolJson(
          await tools['vault_rotate_secret']!.handler({'format': 'json'}),
        );
        expect(allRotated['scope'], 'vault');
        expect(allRotated['rotated_count'], 2);
      },
    );
  });

  group('vault crypto helpers', () {
    test('VaultCrypto is reversible and rejects wrong password', () {
      const password = 's3cret-pass';
      const value = 'very-sensitive';
      final encoded = VaultCrypto.encryptToEnvelope(value, password: password);
      expect(encoded['version'], 1);
      final decoded = VaultCrypto.decryptFromEnvelope(
        encoded,
        password: password,
      );
      expect(decoded, value);
      expect(
        () =>
            VaultCrypto.decryptFromEnvelope(encoded, password: 'bad-password'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
