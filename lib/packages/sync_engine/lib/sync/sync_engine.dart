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

      // Handle fatal errors (e.g., branch not found, invalid URL)
      if (config.syncStatus == SyncStatus.fatalError) {
        print(
          '[FATAL] Fatal error detected for ${config.url}. Source may be invalid or deleted.',
        );
        print(
          '[FATAL] Full re-sync will NOT fix this. Check the URL or source validity.',
        );
        return SyncResult.failure(
          'Fatal error: Source may be invalid or deleted. Check the URL.',
        );
      }

      // Handle temporary errors (e.g., rate limits, network issues, file write errors)
      if (config.syncStatus == SyncStatus.error || forceFullSync) {
        if (config.syncStatus == SyncStatus.error) {
          print(
            '[WARNING] Sync error detected from last attempt. Re-downloading all files to resolve issues...',
          );
        }
        try {
          final config = await _sourceStore.read(sourceFolder);
          print(
            '[WARNING] Re-downloading all files for ${config.url} to fix sync problems...',
          );
          return await addSource(
            config.url,
          ); // Full re-clone for recoverable errors
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
        // File write errors are recoverable (retry with full clone)
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
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
    } on HttpException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('403') || message.contains('429')) {
        // Rate limit: temporary, retry later (no full clone)
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      } else if (message.contains('404')) {
        // Branch/repo not found: fatal (full clone generally won't help in most cases)
        // keep as just error in case repo became private then back to public or other such cases it just requires a full reclone
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      } else {
        // Other HTTP errors (500, etc.): temporary
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      }
    } on SocketException catch (_) {
      // Network issues(no internet): temporary
      // Just ignore it, it will be fixed when connecting to the internet
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.idle);
      return SyncResult.failure(
        'Offline: Retry when connected to the internet.',
      );
    } catch (e) {
      // Default to temporary error
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
      rethrow;
    }
  }
}

// // just a quick test that can be run directly executing this file
// void main() async {
//   final appFolder = Directory('/tmp/classhub');
//   final syncEngine = SyncEngine(appFolder: appFolder);
//   final parser = GithubParser();
//   var url;
//
//   late SyncResult result;
//   // result = await syncEngine.addSource('https://github.com/octocat/Hello-World');
//   // print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');
//
//   // result = await syncEngine.addSource(
//   //   'https://github.com/titanknis/Hello-World',
//   // );
//   // print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');
//
//   url = "https://github.com/titanknis/nixos";
//   // result = await syncEngine.addSource(url);
//   result = await syncEngine.syncSource(
//     Directory('${appFolder.path}/${parser.getSourceFolderName(url)}'),
//   );
//   print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');
//
//   // result = await syncEngine.addSource(
//   //   'https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2',
//   // );
//   // print(result.success ? 'Sync successful!' : 'Sync failed: ${result.error}');
// }
