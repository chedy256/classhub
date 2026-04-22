import 'package:test/test.dart';
import 'package:sync_engine/sync/models/source_config.dart';

void main() {
  group('SourceConfig', () {
    final validJson = {
      'type': 'github',
      'url': 'https://github.com/user/repo',
      'sync_status': 'idle',
      'manifest_version': 1,
      'last_synced_at': '2025-01-15T10:30:00.000Z',
      'checkpoint': 'a3f9c1d',
    };

    test('fromJson parses all fields correctly', () {
      final config = SourceConfig.fromJson(validJson);

      expect(config.type, SourceType.github);
      expect(config.url, 'https://github.com/user/repo');
      expect(config.syncStatus, SyncStatus.idle);
      expect(config.manifestVersion, 1);
      expect(config.lastSyncedAt, DateTime.utc(2025, 1, 15, 10, 30));
      expect(config.checkpoint, 'a3f9c1d');
    });

    test('fromJson handles null optional fields', () {
      final json = {...validJson, 'last_synced_at': null, 'checkpoint': null};
      final config = SourceConfig.fromJson(json);

      expect(config.lastSyncedAt, isNull);
      expect(config.checkpoint, isNull);
    });

    test('toJson round-trips back to identical config', () {
      final config = SourceConfig.fromJson(validJson);
      final result = SourceConfig.fromJson(config.toJson());

      expect(result.type, config.type);
      expect(result.url, config.url);
      expect(result.syncStatus, config.syncStatus);
      expect(result.manifestVersion, config.manifestVersion);
      expect(result.lastSyncedAt, config.lastSyncedAt);
      expect(result.checkpoint, config.checkpoint);
    });

    test('toJson emits null for missing optional fields', () {
      final config = SourceConfig.fromJson({
        ...validJson,
        'last_synced_at': null,
        'last_synced_commit': null,
      });
      final json = config.toJson();

      expect(json['last_synced_at'], isNull);
      expect(json['last_synced_commit'], isNull);
    });

    test('fromJson throws on unknown source type', () {
      final json = {...validJson, 'type': 'dropbox'};
      expect(() => SourceConfig.fromJson(json), throwsArgumentError);
    });

    test('fromJson throws on unknown sync status', () {
      final json = {...validJson, 'sync_status': 'pending'};
      expect(() => SourceConfig.fromJson(json), throwsArgumentError);
    });

    group('copyWith', () {
      test('updates only syncStatus', () {
        final config = SourceConfig.fromJson(validJson);
        final updated = config.copyWith(syncStatus: SyncStatus.syncing);

        expect(updated.syncStatus, SyncStatus.syncing);
        expect(updated.url, config.url);
        expect(updated.checkpoint, config.checkpoint);
      });

      test('updates only checkpoint', () {
        final config = SourceConfig.fromJson(validJson);
        final updated = config.copyWith(checkpoint: 'newsha123');

        expect(updated.checkpoint, 'newsha123');
        expect(updated.syncStatus, config.syncStatus);
        expect(updated.url, config.url);
      });

      test('does not mutate original', () {
        final config = SourceConfig.fromJson(validJson);
        config.copyWith(syncStatus: SyncStatus.error);

        expect(config.syncStatus, SyncStatus.idle);
      });
    });
  });
}
