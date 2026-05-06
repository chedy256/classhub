import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'models/source_config.dart';
import 'models/sync_result.dart';
import 'models/sync_queue.dart';
import 'models/sync_progress.dart';
import 'models/file_delta.dart';

import 'services/source_store.dart';
import 'services/file_writer.dart';
import 'services/sync_queue_service.dart';
import 'services/lock_service.dart';

import 'sources/source_parser.dart';
import 'sources/source_syncer.dart';

import 'sources/github/syncer.dart';
import 'sources/github/parser.dart';

// import 'sources/classroom/syncer.dart';
// import 'sources/classroom/parser.dart';
//
// import 'sources/drive/syncer.dart';
// import 'sources/drive/parser.dart';

String _generateSyncId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return 'sync_${timestamp}_$random';
}

class SyncEngine {
  final Directory appFolder;
  final Duration lockStalenessDuration;
  final bool verbose;
  final SourceStore _sourceStore;
  final FileWriter _fileWriter;
  final SyncQueueService _queueService;
  final LockService _lockService;
  final List<SourceParser> _parsers;
  final Map<SourceType, SourceSyncer> _syncers;
  final SyncProgressCallback? onProgress;

  SyncEngine({
    required this.appFolder,
    this.lockStalenessDuration = const Duration(seconds: 10),
    this.verbose = false,
    SourceStore? sourceStore,
    FileWriter? fileWriter,
    SyncQueueService? queueService,
    LockService? lockService,
    List<SourceParser>? parsers,
    Map<SourceType, SourceSyncer>? syncers,
    this.onProgress,
  }) : _sourceStore = sourceStore ?? SourceStore(),
        _fileWriter = fileWriter ?? FileWriter(),
        _queueService = queueService ?? SyncQueueService(),
        _lockService = lockService ?? LockService(),
        _parsers = parsers ?? [GithubParser()],
        _syncers = syncers ?? {SourceType.github: GithubSyncer()};

  /// Adds a new source by parsing its URL, creating the source folder,
  /// and performing the initial sync. On failure, the partial folder is
  /// preserved for crash recovery via the sync queue.
  Future<SyncResult> addSource(String url) async {
    final parser = _getParserForUrl(url);
    final sourceFolderName = parser.getSourceFolderName(url);
    final sourceFolder = Directory('${appFolder.path}/$sourceFolderName');

    try {
      if (await sourceFolder.exists()) {
        final existingQueue = await _queueService.read(sourceFolder);
        if (existingQueue != null) {
          final sourceFolderName = sourceFolder.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last;
          return await _performSync(
            sourceFolder,
            sourceFolderName: sourceFolderName,
          );
        }
        return SyncResult.failure('Source folder already exists');
      }

      final config = await parser.parseUrlToSourceConfig(url);

      await sourceFolder.create(recursive: true);
      await _sourceStore.write(sourceFolder, config);

      return await _performSync(
        sourceFolder,
        sourceFolderName: sourceFolderName,
      );
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
      final sourceFolderName = sourceFolder.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;

      return await _performSync(
        sourceFolder,
        sourceFolderName: sourceFolderName,
      );
    } catch (e) {
      print('[ERROR] Failed to sync source: $e');
      return SyncResult.failure('Failed to sync source: $e');
    }
  }

  // -- Private ----------------------------------------------------------------

  void _onProgress(SyncProgress progress) {
    if (verbose) {
      final op = progress.currentOperation?.toUpperCase() ?? '';
      final file = progress.currentFile ?? '';
      final pct = progress.totalBytes != null
          ? ((progress.byteProgress ?? 0) * 100).toInt()
          : (progress.progress * 100).toInt();
      final buffer = StringBuffer('[$pct%] $op $file');
      if (progress.totalBytes != null) {
        final done = _formatBytes(progress.completedBytes);
        final total = _formatBytes(progress.totalBytes!);
        buffer.write(' ($done / $total)');
      }
      print(buffer.toString());
    }
    onProgress?.call(progress);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  SourceParser _getParserForUrl(String url) {
    for (final parser in _parsers) {
      if (parser.canParse(url)) return parser;
    }
    throw ArgumentError('Unsupported source URL: $url');
  }

  SourceSyncer _getSyncerForType(SourceType type) => _syncers[type]!;

  Future<SyncResult> _performSync(
    Directory sourceFolder, {
    required String sourceFolderName,
  }) async {
    if (!_lockService.tryAcquire(
      sourceFolder.parent,
      sourceFolderName,
      lockStalenessDuration,
    )) {
      return SyncResult.failure('Sync already in progress');
    }

    SyncQueue? existingQueue;
    existingQueue = await _queueService.read(sourceFolder);
    if (existingQueue != null && existingQueue.completedCount == 0) {
      await _queueService.delete(sourceFolder);
      existingQueue = null;
    }

    Timer? heartbeat;
    try {
      heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
        _lockService.refresh(sourceFolder.parent, sourceFolderName);
      });

      await _sourceStore.updateStatus(sourceFolder, SyncStatus.syncing);
      final config = await _sourceStore.read(sourceFolder);

      final syncId = existingQueue?.syncId ?? _generateSyncId();
      final String? checkpoint;
      final SyncQueue queue;

      if (existingQueue != null) {
        queue = existingQueue;
        checkpoint = existingQueue.checkpoint;
      } else {
        final syncer = _getSyncerForType(config.type);
        final output = await syncer.getDeltas(config);
        checkpoint = output.checkpoint;
        queue = _buildQueueFromDeltas(syncId, output.deltas, checkpoint);
      }

      await _queueService.write(sourceFolder, queue);

      int filesAdded = 0;
      int filesUpdated = 0;
      int filesDeleted = 0;

      SyncQueue currentQueue = queue;

      final pendingDeltas = currentQueue.pendingDeltas;
      final deltasToApply = <FileDelta>[];

      for (final queueDelta in pendingDeltas) {
        final delta = FileDelta(
          relativePath: queueDelta.relativePath,
          type: _deltaTypeFromString(queueDelta.operation ?? 'add'),
          downloadUrl: queueDelta.downloadUrl,
          size: queueDelta.size,
        );
        deltasToApply.add(delta);
      }

      final result = await _fileWriter.apply(
        sourceFolder,
        deltasToApply,
        onFileProgress: (relativePath, operation) async {
          final queueDeltaIndex = currentQueue.deltas.indexWhere(
            (d) => d.relativePath == relativePath,
          );
          if (queueDeltaIndex != -1) {
            final updatedDeltas = List<SyncQueueDelta>.from(
              currentQueue.deltas,
            );
            updatedDeltas[queueDeltaIndex] = updatedDeltas[queueDeltaIndex]
                .copyWith(status: DeltaStatus.done);
            currentQueue = currentQueue.copyWith(deltas: updatedDeltas);
            await _queueService.write(sourceFolder, currentQueue);

            _onProgress(
              SyncProgress(
                syncId: syncId,
                total: queue.totalDeltas,
                completed: currentQueue.completedCount,
                filesAdded: filesAdded,
                filesUpdated: filesUpdated,
                filesDeleted: filesDeleted,
                currentFile: relativePath,
                currentOperation: operation,
                totalBytes: queue.totalBytes > 0 ? queue.totalBytes : null,
                completedBytes: currentQueue.completedBytes,
              ),
            );
          }

          if (operation == 'add') {
            filesAdded++;
          } else if (operation == 'update') {
            filesUpdated++;
          } else if (operation == 'delete') {
            filesDeleted++;
          }
        },
      );

      if (result.hasErrors) {
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        throw Exception('File write errors: ${result.errors.join(", ")}');
      }

      await _queueService.delete(sourceFolder);

      await _sourceStore.markSyncComplete(sourceFolder, checkpoint: checkpoint);

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
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      } else if (message.contains('404')) {
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      } else {
        await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
        rethrow;
      }
    } on SocketException catch (_) {
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.idle);
      return SyncResult.failure(
        'Offline: Retry when connected to the internet.',
      );
    } catch (e) {
      await _sourceStore.updateStatus(sourceFolder, SyncStatus.error);
      rethrow;
    } finally {
      heartbeat?.cancel();
      await _lockService.release(sourceFolder.parent, sourceFolderName);
    }
  }

  SyncQueue _buildQueueFromDeltas(
    String syncId,
    List<FileDelta> deltas,
    String? checkpoint,
  ) {
    final queueDeltas = deltas.map((delta) {
      return SyncQueueDelta(
        relativePath: delta.relativePath,
        status: DeltaStatus.pending,
        downloadUrl: delta.downloadUrl,
        operation: delta.type.name,
        size: delta.size,
      );
    }).toList();

    return SyncQueue(
      syncId: syncId,
      startedAt: DateTime.now().toUtc(),
      deltas: queueDeltas,
      checkpoint: checkpoint,
      totalDeltas: queueDeltas.length,
    );
  }

  DeltaType _deltaTypeFromString(String operation) {
    switch (operation) {
      case 'add':
        return DeltaType.add;
      case 'update':
        return DeltaType.update;
      case 'delete':
        return DeltaType.delete;
      default:
        return DeltaType.add;
    }
  }
}
