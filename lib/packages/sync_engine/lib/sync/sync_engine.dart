import 'dart:io';

import 'models/source_config.dart';
import 'models/sync_result.dart';

import 'services/source_store.dart';
import 'services/file_writer.dart';

import 'sources/source_parser.dart';
import 'sources/source_syncer.dart';

import 'sources/github/syncer.dart';
import 'sources/github/parser.dart';

// import 'sources/classroom/syncer.dart';
// import 'sources/classroom/parser.dart';
//
// import 'sources/drive/syncer.dart';
// import 'sources/drive/parser.dart';

class SyncEngine {
  final Directory appFolder;
  final SourceStore _sourceStore;
  final FileWriter _fileWriter;
  final List<SourceParser> _parsers;
  final Map<SourceType, SourceSyncer> _syncers;

  SyncEngine({
    required this.appFolder,
    SourceStore? sourceStore,
    FileWriter? fileWriter,
    List<SourceParser>? parsers,
    Map<SourceType, SourceSyncer>? syncers,
  }) : _sourceStore = sourceStore ?? SourceStore(),
       _fileWriter = fileWriter ?? FileWriter(),
       _parsers =
           parsers ??
           [
             GithubParser(),
             // DriveParser(),
             // ClassroomParser(),
           ],
       _syncers =
           syncers ??
           {
             SourceType.github: GithubSyncer(),
             // SourceType.drive: DriveSyncer(),
             // SourceType.classroom: ClassroomSyncer(),
           };

  /// Adds a new source by parsing its URL, creating the source folder,
  /// and performing the initial sync.
  Future<SyncResult> addSource(String url) async {
    try {
      final parser = _getParserForUrl(url);
      final sourceFolderName = parser.getSourceFolderName(url);
      final sourceFolder = Directory('${appFolder.path}/$sourceFolderName');
      await sourceFolder.create(recursive: true);

      final config = await parser.parseUrlToSourceConfig(url);
      await _sourceStore.write(sourceFolder, config);

      return await _performSync(sourceFolder);
    } catch (e) {
      print('[ERROR] Failed to add source: $e');
      return SyncResult.failure('Failed to add source: $e');
    }
  }

  /// Performs the sync operation for an existing source.
  Future<SyncResult> syncSource(
    Directory sourceFolder, {
    bool forceFullSync = false,
  }) async {
    try {
      final config = await _sourceStore.read(sourceFolder);
      if (config.syncStatus == SyncStatus.error || forceFullSync) {
        print(
          '[WARNING] Sync error detected from last attempt. Re-downloading all files to resolve issues...',
        );
        try {
          // Read the existing config to get the URL
          final config = await _sourceStore.read(sourceFolder);
          print(
            '[WARNING] Re-downloading all files for ${config.url} to fix sync problems...',
          );

          // Re-add the source (this will overwrite the existing config and re-sync)
          return await addSource(config.url);
        } catch (e) {
          print('[ERROR] Failed to fix source: $e');
          return SyncResult.failure('Failed to fix source: $e');
        }
      }
      return await _performSync(sourceFolder);
    } catch (e) {
      print('[ERROR] Failed to sync source: $e');
      return SyncResult.failure('Failed to sync source: $e');
    }
  }

  // -- Private ----------------------------------------------------------------

  SourceParser _getParserForUrl(String url) {
    for (final parser in _parsers) {
      if (parser.canParse(url)) return parser;
    }
    throw ArgumentError('Unsupported source URL: $url');
  }

  SourceSyncer _getSyncerForType(SourceType type) => _syncers[type]!;

  Future<SyncResult> _performSync(Directory sourceFolder) async {
    try {
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.syncing);
      final config = await _sourceStore.read(sourceFolder);
      final syncer = _getSyncerForType(config.type);
      final output = await syncer.getDeltas(config);
      final result = await _fileWriter.apply(sourceFolder, output.deltas);

      if (result.hasErrors) {
        throw Exception('File write errors: ${result.errors.join(", ")}');
      }

      await _sourceStore.markSyncComplete(
        sourceFolder,
        checkpoint: output.checkpoint,
      );

      return SyncResult(
        success: true,
        syncedAt: DateTime.now().toUtc(),
        filesAdded: result.filesAdded,
        filesUpdated: result.filesUpdated,
        filesDeleted: result.filesDeleted,
      );
    } catch (e) {
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
      rethrow; // Propagate the exception to `syncSource` for printing
    }
  }
}

// just a quick test that can be run directly executing this file
void main() async {
  final appFolder = Directory('/tmp/classhub');
  final syncEngine = SyncEngine(appFolder: appFolder);

  late SyncResult result;
  result = await syncEngine.addSource('https://github.com/octocat/Hello-World');
  print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');

  // result = await syncEngine.addSource(
  //   'https://github.com/titanknis/Hello-World',
  // );
  // print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');

  result = await syncEngine.addSource('https://github.com/titanknis/nixos');
  print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');

  // result = await syncEngine.addSource(
  //   'https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2',
  // );
  // print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');
}
