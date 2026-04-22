// lib/sync/models/sync_result.dart

class SyncResult {
  // NOTE: consider making the syncedAt parameter optional
  final bool success;
  final int filesAdded;
  final int filesUpdated;
  final int filesDeleted;
  final String? error; // null on success
  final DateTime syncedAt;

  const SyncResult({
    required this.success,
    required this.syncedAt,
    this.filesAdded = 0,
    this.filesUpdated = 0,
    this.filesDeleted = 0,
    this.error,
  });

  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      syncedAt: DateTime.now().toUtc(),
      error: error,
    );
  }

  int get totalChanges => filesAdded + filesUpdated + filesDeleted;
}
