import '../models/source_config.dart';
import '../models/syncer_output.dart';

abstract class SourceSyncer {
  /// Returns the file changes needed to bring the local folder
  /// in sync with the remote source, plus a checkpoint the engine
  /// can persist so the next sync can be incremental.
  Future<SyncerOutput> getDeltas(SourceConfig config);
}
