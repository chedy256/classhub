// lib/sync/services/sync_queue_service.dart

import 'dart:convert';
import 'dart:io';

import '../models/sync_queue.dart';

/// Service for reading and writing `.sync_queue.json` files.
///
/// The queue file lives in the temp folder during a sync operation
/// and is used for crash recovery and resume capabilities.
class SyncQueueService {
  static const String _queueFileName = '.sync_queue.json';

  /// Writes the sync queue to the temp folder.
  Future<void> write(Directory tempFolder, SyncQueue queue) async {
    final queueFile = File('${tempFolder.path}/$_queueFileName');
    final json = jsonEncode(queue.toJson());
    await queueFile.writeAsString(json, flush: true);
  }

  /// Reads the sync queue from the temp folder.
  ///
  /// Returns null if no queue file exists.
  Future<SyncQueue?> read(Directory tempFolder) async {
    final queueFile = File('${tempFolder.path}/$_queueFileName');
    if (!await queueFile.exists()) return null;

    final content = await queueFile.readAsString();
    return SyncQueue.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  /// Deletes the sync queue file from the temp folder.
  Future<void> delete(Directory tempFolder) async {
    final queueFile = File('${tempFolder.path}/$_queueFileName');
    if (await queueFile.exists()) {
      await queueFile.delete();
    }
  }

  /// Checks if a sync queue file exists in the temp folder.
  Future<bool> exists(Directory tempFolder) async {
    final queueFile = File('${tempFolder.path}/$_queueFileName');
    return await queueFile.exists();
  }
}
