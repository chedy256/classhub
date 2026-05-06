// lib/sync/models/sync_queue.dart

/// Status of an individual delta operation in the sync queue.
enum DeltaStatus { pending, in_progress, done, failed }

/// Tracks a single delta operation in the sync queue.
class SyncQueueDelta {
  final String relativePath;
  final DeltaStatus status;
  final String? downloadUrl; // null for deletes
  final String? operation; // 'add', 'update', 'delete'
  final int? size; // in bytes, null when unknown

  const SyncQueueDelta({
    required this.relativePath,
    required this.status,
    this.downloadUrl,
    this.operation,
    this.size,
  });

  factory SyncQueueDelta.fromJson(Map<String, dynamic> json) {
    return SyncQueueDelta(
      relativePath: json['relative_path'] as String,
      status: DeltaStatus.values.byName(json['status'] as String),
      downloadUrl: json['download_url'] as String?,
      operation: json['operation'] as String?,
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relative_path': relativePath,
      'status': status.name,
      'download_url': downloadUrl,
      'operation': operation,
      'size': size,
    };
  }

  SyncQueueDelta copyWith({DeltaStatus? status}) {
    return SyncQueueDelta(
      relativePath: relativePath,
      status: status ?? this.status,
      downloadUrl: downloadUrl,
      operation: operation,
      size: size,
    );
  }
}

/// Represents the full sync queue for a single sync operation.
///
/// Stored as `.sync_queue.json` inside the temp folder during sync.
/// Used for crash recovery: if the app crashes, the queue can be
/// read to resume from where it left off.
class SyncQueue {
  final String syncId; // unique identifier for this sync operation
  final DateTime startedAt;
  final String? checkpoint; // the checkpoint being synced to
  final List<SyncQueueDelta> deltas;
  final int totalDeltas;

  SyncQueue({
    required this.syncId,
    required this.startedAt,
    required this.deltas,
    this.checkpoint,
    this.totalDeltas = 0,
  });

  factory SyncQueue.fromJson(Map<String, dynamic> json) {
    return SyncQueue(
      syncId: json['sync_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      checkpoint: json['checkpoint'] as String?,
      deltas: (json['deltas'] as List)
          .map((d) => SyncQueueDelta.fromJson(d as Map<String, dynamic>))
          .toList(),
      totalDeltas: json['total_deltas'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sync_id': syncId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'checkpoint': checkpoint,
      'total_deltas': totalDeltas,
      'deltas': deltas.map((d) => d.toJson()).toList(),
    };
  }

  /// Returns deltas that still need to be processed.
  List<SyncQueueDelta> get pendingDeltas =>
      deltas.where((d) => d.status != DeltaStatus.done).toList();

  /// Returns the count of completed deltas.
  int get completedCount => deltas.where((d) => d.status == DeltaStatus.done).length;

  /// Returns the count of pending deltas.
  int get pendingCount => deltas.where((d) => d.status == DeltaStatus.pending).length;

  /// Returns whether all deltas are complete.
  bool get isComplete => pendingCount == 0;

  /// Returns progress as a fraction (0.0 to 1.0) by file count.
  double get progress => totalDeltas == 0 ? 1.0 : completedCount / totalDeltas;

  int get totalBytes => deltas.where((d) => d.size != null).fold<int>(
    0,
    (sum, d) => sum + (d.size ?? 0),
  );

  int get completedBytes =>
      deltas.where((d) => d.status == DeltaStatus.done && d.size != null).fold<int>(
        0,
        (sum, d) => sum + d.size!,
      );

  double? get byteProgress => totalBytes == 0 ? null : completedBytes / totalBytes;

  SyncQueue copyWith({List<SyncQueueDelta>? deltas}) {
    return SyncQueue(
      syncId: syncId,
      startedAt: startedAt,
      checkpoint: checkpoint,
      deltas: deltas ?? this.deltas,
      totalDeltas: totalDeltas,
    );
  }
}
