// test/integration/sync_engine_integration_test.dart
import 'package:test/test.dart';
import 'package:sync_engine/sync_engine.dart';
import 'package:sync_engine/sync/models/source_config.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

void main() {
  late SyncEngine syncEngine;
  late Directory testDir;

  setUp(() async {
    // Create a temporary directory for testing
    testDir = await Directory.systemTemp.createTemp('sync_engine_test_');
  });

  tearDown(() async {
    // Clean up the test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('SyncEngine Integration Tests', () {
    test(
      'Full workflow: add and sync a real GitHub repository',
      () async {
        // Use a small, public repository for testing
        const testRepoUrl = 'https://github.com/octocat/Hello-World';

        // Initialize the sync engine with the test directory
        syncEngine = SyncEngine(appFolder: testDir);

        // Add the source
        final addResult = await syncEngine.addSource(testRepoUrl);

        // Verify the source was added successfully
        expect(
          addResult.success,
          isTrue,
          reason: 'Failed to add source: ${addResult.error}',
        );

        // Get the source folder path
        final repoName = path.basename(testRepoUrl);
        final sourceFolder = Directory(path.join(testDir.path, repoName));

        // Verify the source folder was created
        expect(
          await sourceFolder.exists(),
          isTrue,
          reason: 'Source folder was not created',
        );

        // Verify the .source/source.json file was created
        final sourceConfigFile = File(
          path.join(sourceFolder.path, '.source', 'source.json'),
        );
        expect(
          await sourceConfigFile.exists(),
          isTrue,
          reason: 'source.json was not created',
        );

        // Read and verify the source config
        final configContent = await sourceConfigFile.readAsString();
        final config = SourceConfig.fromJson(
          jsonDecode(configContent) as Map<String, dynamic>,
        );
        expect(config.type, SourceType.github);
        expect(config.url, testRepoUrl);
        expect(config.defaultBranch, isNotNull);
        expect(config.syncStatus, SyncStatus.idle);

        // Sync the source
        final syncResult = await syncEngine.syncSource(sourceFolder);

        // Verify the sync was successful
        expect(
          syncResult.success,
          isTrue,
          reason: 'Failed to sync source: ${syncResult.error}',
        );

        // Verify files were synced (Hello-World repo has a README.md)
        final readmeFile = File(path.join(sourceFolder.path, 'README'));
        expect(
          await readmeFile.exists(),
          isTrue,
          reason: 'README.md was not synced',
        );

        // Verify the checkpoint was updated in source.json
        final updatedConfigContent = await sourceConfigFile.readAsString();
        final updatedConfig = SourceConfig.fromJson(
          jsonDecode(updatedConfigContent) as Map<String, dynamic>,
        );
        expect(
          updatedConfig.checkpoint,
          isNotNull,
          reason: 'Checkpoint was not updated after sync',
        );
        expect(
          updatedConfig.lastSyncedAt,
          isNotNull,
          reason: 'lastSyncedAt was not updated after sync',
        );
      },
      timeout: Timeout(Duration(minutes: 1)),
    ); // GitHub API might be slow

    test('Sync existing source again', () async {
      const testRepoUrl = 'https://github.com/octocat/Hello-World';
      syncEngine = SyncEngine(appFolder: testDir);

      // Add the source
      await syncEngine.addSource(testRepoUrl);
      final repoName = path.basename(testRepoUrl);
      final sourceFolder = Directory(path.join(testDir.path, repoName));

      // First sync
      final firstSyncResult = await syncEngine.syncSource(sourceFolder);
      expect(firstSyncResult.success, isTrue);

      // Read the checkpoint from the first sync
      final sourceConfigFile = File(
        path.join(sourceFolder.path, '.source', 'source.json'),
      );
      final configContent = await sourceConfigFile.readAsString();
      final config = SourceConfig.fromJson(
        jsonDecode(configContent) as Map<String, dynamic>,
      );
      final firstCheckpoint = config.checkpoint;

      // Second sync (should be incremental)
      final secondSyncResult = await syncEngine.syncSource(sourceFolder);
      expect(secondSyncResult.success, isTrue);

      // Verify the checkpoint was updated (might be the same if no changes)
      final updatedConfigContent = await sourceConfigFile.readAsString();
      final updatedConfig = SourceConfig.fromJson(
        jsonDecode(updatedConfigContent) as Map<String, dynamic>,
      );
      expect(updatedConfig.checkpoint, isNotNull);
    }, timeout: Timeout(Duration(minutes: 1)));

    test('Handle invalid GitHub URL', () async {
      syncEngine = SyncEngine(appFolder: testDir);

      // Try to add an invalid URL
      final result = await syncEngine.addSource(
        'https://github.com/nonexistent/repo',
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    }, timeout: Timeout(Duration(minutes: 1)));
  });
}
