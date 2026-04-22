import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:sync_engine/sync/models/source_config.dart';
import 'package:sync_engine/sync/services/source_store.dart';

void main() {
  late Directory tempDir;
  late SourceStore store;

  // A valid base config we reuse across tests
  final baseConfig = SourceConfig(
    type: SourceType.github,
    url: 'https://github.com/user/repo',
    syncStatus: SyncStatus.never,
    manifestVersion: 1,
    defaultBranch: "main",
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('classhub_test_');
    store = SourceStore();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('SourceStore.read', () {
    test('reads a valid source.json correctly', () async {
      await store.write(tempDir, baseConfig);
      final config = await store.read(tempDir);

      expect(config.type, SourceType.github);
      expect(config.url, 'https://github.com/user/repo');
      expect(config.syncStatus, SyncStatus.never);
    });

    test('throws StateError when source.json is missing', () async {
      await expectLater(() => store.read(tempDir), throwsA(isA<StateError>()));
    });

    test('throws when source.json contains malformed JSON', () async {
      final file = File('${tempDir.path}/.source/source.json');
      await file.parent.create(recursive: true);
      await file.writeAsString('this is not json {{{');

      await expectLater(
        () => store.read(tempDir),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SourceStore.write', () {
    test('creates .source directory if it does not exist', () async {
      await store.write(tempDir, baseConfig);

      final dir = Directory('${tempDir.path}/.source');
      expect(await dir.exists(), isTrue);
    });

    test('written file is valid JSON', () async {
      await store.write(tempDir, baseConfig);

      final file = File('${tempDir.path}/.source/source.json');
      final content = await file.readAsString();

      expect(() => jsonDecode(content), returnsNormally);
    });

    test('overwrites existing source.json', () async {
      await store.write(tempDir, baseConfig);
      await store.write(
        tempDir,
        baseConfig.copyWith(syncStatus: SyncStatus.idle),
      );

      final config = await store.read(tempDir);
      expect(config.syncStatus, SyncStatus.idle);
    });
  });

  group('SourceStore.updateStatus', () {
    test('updates only syncStatus, preserves other fields', () async {
      final config = SourceConfig(
        type: SourceType.github,
        url: 'https://github.com/user/repo',
        syncStatus: SyncStatus.idle,
        manifestVersion: 1,
        checkpoint: 'abc123',
      );
      await store.write(tempDir, config);
      await store.updateStatus(tempDir, SyncStatus.syncing);

      final updated = await store.read(tempDir);
      expect(updated.syncStatus, SyncStatus.syncing);
      expect(updated.url, config.url);
      expect(updated.checkpoint, 'abc123');
    });
  });

  group('SourceStore.markSyncComplete', () {
    test('sets status to idle, updates commit sha and timestamp', () async {
      await store.write(tempDir, baseConfig);

      final before = DateTime.now().toUtc();
      await store.markSyncComplete(tempDir, checkpoint: 'newsha456');
      final after = DateTime.now().toUtc();

      final config = await store.read(tempDir);
      expect(config.syncStatus, SyncStatus.idle);
      expect(config.checkpoint, 'newsha456');
      expect(config.lastSyncedAt, isNotNull);
      expect(
        config.lastSyncedAt!.isAfter(before) ||
            config.lastSyncedAt!.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        config.lastSyncedAt!.isBefore(after) ||
            config.lastSyncedAt!.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('preserves url and type after marking complete', () async {
      await store.write(tempDir, baseConfig);
      await store.markSyncComplete(tempDir, checkpoint: 'sha789');

      final config = await store.read(tempDir);
      expect(config.url, baseConfig.url);
      expect(config.type, baseConfig.type);
    });
  });
}
