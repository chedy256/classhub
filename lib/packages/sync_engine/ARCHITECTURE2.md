# Architecture

## Layers

```
┌─────────────────────────────────┐
│  4. SyncEngine (orchestrator)   │  ← what the app calls
├─────────────────────────────────┤
│  3. Source Parsers & Syncers    │  ← GitHub / Drive / Classroom
├─────────────────────────────────┤
│  2. Services (store, writer)    │  ← source.json I/O, file writes, locks, queues
├─────────────────────────────────┤
│  1. Models                      │  ← pure data, no I/O
└─────────────────────────────────┘
```

Each layer only depends on the layer below it. `SyncEngine` does not touch the file system directly. Parsers and syncers do not know about `source.json`.

---

## Layer 1 — Models

Pure Dart classes. No I/O, no logic beyond `fromJson`/`toJson` and simple assertions.

### `FileDelta`

A single file change:

```dart
enum DeltaType { add, update, delete }

class FileDelta {
  final String relativePath;
  final String? downloadUrl; // null for deletes
  final DeltaType type;
  final int? size;           // file size in bytes, used for progress tracking
}
```

### `SourceConfig`

Persisted state for a source:

- `type` — `github | drive | classroom`
- `url` — the original URL
- `syncStatus` — `idle | syncing | error | never | fatalError`
- `manifestVersion` — schema version for the config file
- `checkpoint` — last sync point (e.g. commit SHA for GitHub)
- `defaultBranch` — resolved branch, cached to avoid extra API calls
- `lastSyncedAt` — timestamp of last successful sync

### `SyncResult`

Returned to the caller after a sync:

- `success`, `error`, `syncedAt`
- `filesAdded`, `filesUpdated`, `filesDeleted`, `totalChanges`

### `SyncerOutput`

Returned by a syncer after fetching deltas:

- `deltas` — list of `FileDelta`
- `checkpoint` — new checkpoint to persist

### `SyncProgress`

Emitted during sync for real-time UI updates:

```dart
class SyncProgress {
  final String syncId;
  final int total;
  final int completed;
  final double progress;              // 0.0–1.0 (file count)
  final int filesAdded;
  final int filesUpdated;
  final int filesDeleted;
  final String? currentFile;
  final String? currentOperation;
  final int? totalBytes;              // null if unknown
  final int completedBytes;
  final double? byteProgress;         // 0.0–1.0 (bytes)
}
```

### `SyncQueue`

Serializable queue of pending file operations, persisted as `.sync_queue.json` inside the source folder during sync:

```dart
class SyncQueue {
  final String syncId;
  final DateTime startedAt;
  final List<SyncQueueDelta> deltas;
  final String? checkpoint;
  final int totalDeltas;
  int get completedCount;
  int get totalBytes;
  int get completedBytes;
  List<SyncQueueDelta> get pendingDeltas;
}
```

Each `SyncQueueDelta` wraps a `FileDelta` with a status (`pending | done`), enabling crash recovery.

### `DeltaStatus`

```dart
enum DeltaStatus { pending, done }
```

---

## Layer 2 — Services

### `SourceStore`

Reads and writes `.source/source.json` inside a source folder.

Key methods:

- `read(sourceFolder)` — async, returns `SourceConfig`, throws if missing or malformed
- `readSync(sourceFolder)` — sync version, returns `SourceConfig?`, null on error
- `existsSync(sourceFolder)` — sync check if source.json exists
- `write(sourceFolder, config)` — writes config to disk, creates parent dir if needed
- `updateStatus(sourceFolder, status)` — updates `syncStatus` only
- `markSyncComplete(sourceFolder, {checkpoint})` — sets status to `idle`, updates `lastSyncedAt` and `checkpoint`

### `FileWriter`

Applies a list of `FileDelta` to a local directory.

- Downloads files for `add` and `update` deltas
- Deletes files for `delete` deltas (idempotent — no error if already gone)
- Creates intermediate directories as needed
- Guards against path traversal attacks
- Records per-file errors without aborting the whole batch
- Accepts an `onFileProgress` callback for real-time progress

### `LockService`

Prevents concurrent syncs using file-based locks.

- Lock file path: `{appFolder}/{sourceName}.sync.lock`
- `tryAcquire(parent, name, staleness)` — creates lock, returns false if one already exists and is fresh
- `refresh(parent, name)` — updates lock mtime (called every 5s during sync)
- `release(parent, name)` — deletes lock file
- `exists(parent, name)` — checks if lock exists
- `deleteLock(parent, name)` — force-deletes lock (used during crash recovery)

Lock staleness is configurable (default 6s). On app launch, **all** locks are considered stale since no heartbeat is running.

### `SyncQueueService`

Manages `.sync_queue.json` for resumable syncs.

- `read(sourceFolder)` — returns `SyncQueue?`
- `write(sourceFolder, queue)` — persists queue to disk
- `delete(sourceFolder)` — removes queue after successful sync
- `hasPending(sourceFolder)` — checks if a pending queue exists

---

## Layer 3 — Parsers & Syncers

Each source type implements two interfaces:

### `SourceParser`

```dart
abstract class SourceParser {
  SourceType get sourceType;
  bool canParse(String url);
  Future<SourceConfig> parseUrlToSourceConfig(String url);
  String getSourceFolderName(String url);
}
```

### `SourceSyncer`

```dart
abstract class SourceSyncer {
  Future<SyncerOutput> getDeltas(SourceConfig config);
}
```

### GitHub implementation

**`GithubParser`** — parses `https://github.com/owner/repo` (and SSH / branch URL variants like `github.com/owner/repo/tree/my-branch`). Resolves the default branch via the GitHub API if not present in the URL. Uses `HttpClient` which accepts an optional `githubToken` for higher rate limits.

**`GithubSyncer`** — fetches file changes via the GitHub API:

- No checkpoint → full clone via the recursive tree API
- Checkpoint present → incremental diff via the compare API
- Renames are split into a delete + add
- Reports `size` for each delta byte progress tracking

### Drive / Classroom

Stubbed. Directory structure exists under `sources/drive/` and `sources/classroom/` but imports are commented out in `SyncEngine`.

---

## Layer 4 — SyncEngine

`SyncEngine` is the public entry point. It holds a list of parsers and a map of syncers, and wires everything together. All services are injectable for testing.

### Constructor

```dart
SyncEngine({
  required Directory appFolder,
  String? githubToken,
  bool verbose = false,
  SyncProgressCallback? onProgress,
  // All services are injectable:
  SourceStore? sourceStore,
  FileWriter? fileWriter,
  SyncQueueService? queueService,
  LockService? lockService,
  List<SourceParser>? parsers,
  Map<SourceType, SourceSyncer>? syncers,
});
```

### `addSource(url)`

1. Find a parser that can handle the URL
2. Create a folder in `appFolder`
3. Write the initial `SourceConfig` to `.source/source.json`
4. Call `_performSync`
5. On failure, the partial folder is preserved for crash recovery

### `syncSource(sourceFolder)`

1. Extract folder name from path
2. Call `_performSync`
3. Return `SyncResult` or failure

### `_performSync(sourceFolder)`

The core sync flow with resumable downloads:

1. **Acquire lock** — `tryAcquire()`, fail if already locked
2. **Check for existing queue** — if a queue exists but has 0 completed deltas, delete it (stale)
3. **Start heartbeat** — refresh lock every 5s
4. **Set status to `syncing`**
5. **Read config**
6. **Fetch or resume deltas**:
   - If queue exists → reuse its checkpoint and deltas
   - Otherwise → call syncer's `getDeltas(config)`, build a new queue
7. **Write queue** to disk
8. **Apply deltas** one-by-one via `FileWriter`:
   - Mark each delta as `done` in the queue
   - Emit `SyncProgress` callback after each file
9. **Check for write errors** — if any, set status to `error` and throw
10. **Delete queue** — sync succeeded, no recovery needed
11. **Mark complete** — update `SourceStore` with status `idle`, checkpoint, timestamp
12. **Release lock** in `finally` block (also cancels heartbeat)

### `detectStaleSyncs(appFolder)`

Static method for crash recovery. Scans all top-level directories in `appFolder` for:

- Any `.sync.lock` file (all considered stale on launch)
- Any `.sync_queue.json` with pending deltas

Returns a list of `Directory` objects that need to resume. The app is responsible for deleting the stale locks before calling `syncSource()` on each.

---

## Sync Flow Summary

### Normal sync

```
App → SyncEngine.addSource(url)
         ↓
  parser.parseUrlToSourceConfig(url) → SourceConfig
         ↓
  SourceStore.write() → .source/source.json
         ↓
  _performSync()
    → lockService.tryAcquire()
    → SourceStore.updateStatus(syncing)
    → syncer.getDeltas(config) → SyncerOutput
    → Build SyncQueue → SyncQueueService.write()
    → FileWriter.apply() + onFileProgress → marks deltas done
    → SyncQueueService.delete()
    → SourceStore.markSyncComplete()
    → lockService.release()
    → return SyncResult
```

### Resumable sync (after crash/interruption)

```
App launch
  → SyncEngine.detectStaleSyncs() → list of stale sources
  → LockService.deleteLock() for each
  → SyncEngine.syncSource() for each
       ↓
  _performSync()
    → lockService.tryAcquire()
    → SyncQueueService.read() → existing queue with pending deltas
    → Skip syncer.getDeltas(), reuse checkpoint and deltas
    → Apply only pending deltas
    → Mark complete → delete queue → release lock
```

### Concurrent sync protection

```
Thread A: lockService.tryAcquire() → true  → proceeds
Thread B: lockService.tryAcquire() → false → SyncResult.failure('Sync already in progress')
Thread A: heartbeat refreshes lock every 5s
Thread A: lockService.release() → lock deleted
```
