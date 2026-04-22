import 'dart:io';

import 'sync/models/source_config.dart';
import 'sync/models/sync_result.dart';

import 'sync/services/source_store.dart';
import 'sync/services/file_writer.dart';

import 'sync/sources/source_parser.dart';
import 'sync/sources/source_syncer.dart';

import 'sync/sources/github/syncer.dart';
import 'sync/sources/github/parser.dart';

// import 'sync/sources/classroom/syncer.dart';
// import 'sync/sources/classroom/parser.dart';
//
// import 'sync/sources/drive/syncer.dart';
// import 'sync/sources/drive/parser.dart';

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
      return SyncResult.failure('Failed to add source: $e');
    }
  }

  /// Performs the sync operation for an existing source.
  Future<SyncResult> syncSource(Directory sourceFolder) async {
    try {
      return await _performSync(sourceFolder);
    } catch (e) {
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
      return SyncResult.failure('Sync failed: $e');
    }
  }
}

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

// export SyncEngine;
// library;
//
// export 'sync/models/source_config.dart';
// export 'sync/models/file_delta.dart';
// export 'sync/models/sync_result.dart';
// export 'sync/services/source_store.dart';
//
// // TODO: Export any libraries intended for clients of this package.
