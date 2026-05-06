// lib/sync/services/source_store.dart

import 'dart:convert';
import 'dart:io';
import '../models/source_config.dart';

class SourceStore {
  static const _sourceDirName = '.source';
  static const _sourceFileName = 'source.json';

  File _sourceFile(Directory sourceFolder) {
    return File('${sourceFolder.path}/$_sourceDirName/$_sourceFileName');
  }

  /// Checks if source.json exists in the given source folder synchronously.
  bool existsSync(Directory sourceFolder) {
    return _sourceFile(sourceFolder).existsSync();
  }

  /// Reads source.json from the given source folder synchronously.
  /// Returns null if the file doesn't exist or is malformed.
  SourceConfig? readSync(Directory sourceFolder) {
    try {
      final file = _sourceFile(sourceFolder);
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return SourceConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Reads source.json from the given source folder.
  /// Throws if the file doesn't exist or is malformed.
  Future<SourceConfig> read(Directory sourceFolder) async {
    final file = _sourceFile(sourceFolder);

    if (!await file.exists()) {
      throw StateError('source.json not found at ${file.path}');
    }

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return SourceConfig.fromJson(json);
  }

  /// Writes the full config to source.json, creating the file if needed.
  Future<void> write(Directory sourceFolder, SourceConfig config) async {
    final file = _sourceFile(sourceFolder);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
  }

  /// Convenience: update only sync_status (called at sync start/on error).
  Future<void> updateStatus(Directory sourceFolder, SyncStatus status) async {
    final config = await read(sourceFolder);
    await write(sourceFolder, config.copyWith(syncStatus: status));
  }

  /// Convenience: stamp a successful sync.
  ///
  /// Persists [checkpoint] (the commit SHA for GitHub), [resolvedBranch]
  /// (so future syncs skip the branch API call), and the current timestamp.
  /// Fields left null are preserved from the existing config.
  Future<void> markSyncComplete(
    // TODO: make the directory required(put it on hold to test later and not break what i am working on and get things complicated)
    Directory sourceFolder, {
    required String? checkpoint,
  }) async {
    final config = await read(sourceFolder);
    await write(
      sourceFolder,
      config.copyWith(
        syncStatus: SyncStatus.idle,
        lastSyncedAt: DateTime.now().toUtc(),
        checkpoint: checkpoint,
      ),
    );
  }
}
