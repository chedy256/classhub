// lib/sync/models/sync_progress.dart

/// Represents the current progress of a sync operation.
class SyncProgress {
  final String syncId;
  final int total;
  final int completed;
  final int filesAdded;
  final int filesUpdated;
  final int filesDeleted;
  final String? currentFile; // the file currently being processed
  final String? currentOperation; // 'add', 'update', 'delete'
  final double progress; // 0.0 to 1.0 (by file count)
  final int? totalBytes; // null when sizes unknown (incremental diff)
  final int completedBytes;
  final double? byteProgress; // null when totalBytes is null

  const SyncProgress({
    required this.syncId,
    required this.total,
    required this.completed,
    this.filesAdded = 0,
    this.filesUpdated = 0,
    this.filesDeleted = 0,
    this.currentFile,
    this.currentOperation,
    this.totalBytes,
    this.completedBytes = 0,
  }) : progress = total == 0 ? 1.0 : completed / total,
       byteProgress = totalBytes == null || totalBytes == 0
           ? null
           : completedBytes / totalBytes;

  /// Creates a copy with updated fields.
  SyncProgress copyWith({
    int? completed,
    int? filesAdded,
    int? filesUpdated,
    int? filesDeleted,
    String? currentFile,
    String? currentOperation,
  }) {
    return SyncProgress(
      syncId: syncId,
      total: total,
      completed: completed ?? this.completed,
      filesAdded: filesAdded ?? this.filesAdded,
      filesUpdated: filesUpdated ?? this.filesUpdated,
      filesDeleted: filesDeleted ?? this.filesDeleted,
      currentFile: currentFile ?? this.currentFile,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }
}

/// Callback type for receiving sync progress updates.
typedef SyncProgressCallback = void Function(SyncProgress progress);
