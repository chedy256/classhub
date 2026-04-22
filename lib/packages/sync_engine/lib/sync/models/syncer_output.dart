// lib/sync/models/syncer_output.dart

import 'file_delta.dart';

class SyncerOutput {
  final List<FileDelta> deltas;
  final String? checkpoint; // e.g., commit SHA for GitHub

  const SyncerOutput({required this.deltas, this.checkpoint});
}
