# Architecture

## Layers

```
┌─────────────────────────────────┐
│  4. SyncEngine (orchestrator)   │  ← what the app calls
├─────────────────────────────────┤
│  3. Source Parsers & Syncers    │  ← GitHub / Drive / Classroom
├─────────────────────────────────┤
│  2. Services (store, writer)    │  ← source.json I/O, file writes
├─────────────────────────────────┤
│  1. Models                      │  ← pure data, no I/O
└─────────────────────────────────┘
```

Each layer only depends on the layer below it. `SyncEngine` does not touch the file system directly. Parsers and syncers do not know about `source.json`.

---

## Layer 1 — Models

Pure Dart classes. No I/O, no logic beyond `fromJson`/`toJson` and simple assertions.

**`FileDelta`** — a single file change:

```dart
enum DeltaType { add, update, delete }

class FileDelta {
  final String relativePath;
  final String? downloadUrl; // null for deletes
  final DeltaType type;
}
```

**`SourceConfig`** — persisted state for a source:

- `type` — `github | drive | classroom`
- `url` — the original URL
- `syncStatus` — `idle | syncing | error | never`
- `checkpoint` — last sync point (e.g. commit SHA for GitHub)
- `defaultBranch` — resolved branch, cached to avoid extra API calls
- `lastSyncedAt` — timestamp of last successful sync

**`SyncResult`** — returned to the caller after a sync:

- `success`, `error`, `syncedAt`
- `filesAdded`, `filesUpdated`, `filesDeleted`, `totalChanges`

**`SyncerOutput`** — returned by a syncer:

- `deltas` — list of `FileDelta`
- `checkpoint` — new checkpoint to persist

---

## Layer 2 — Services

**`SourceStore`** — reads and writes `.source/source.json` inside a source folder.

Key methods:

- `read(sourceFolder)` — returns `SourceConfig`
- `write(sourceFolder, config)` — writes config to disk
- `updateStatus(sourceFolder, status)` — updates `syncStatus` only
- `markSyncComplete(sourceFolder, {checkpoint})` — sets status to `idle`, updates `lastSyncedAt` and `checkpoint`

**`FileWriter`** — applies a list of `FileDelta` to a local directory.

- Downloads files for `add` and `update` deltas
- Deletes files for `delete` deltas (idempotent — no error if already gone)
- Creates intermediate directories as needed
- Guards against path traversal attacks
- Records per-file errors without aborting the whole batch

---

## Layer 3 — Parsers & Syncers

Each source type implements two interfaces:

**`SourceParser`**:

```dart
abstract class SourceParser {
  SourceType get sourceType;
  bool canParse(String url);
  Future<SourceConfig> parseUrlToSourceConfig(String url);
  String getSourceFolderName(String url);
}
```

**`SourceSyncer`**:

```dart
abstract class SourceSyncer {
  Future<SyncerOutput> getDeltas(SourceConfig config);
}
```

### GitHub implementation

**`GithubParser`** — parses `https://github.com/owner/repo` (and SSH / branch URL variants). Resolves the default branch via the GitHub API if not present in the URL.

**`GithubSyncer`** — fetches file changes via the GitHub API:

- No checkpoint → full clone via the recursive tree API
- Checkpoint present → incremental diff via the compare API
- Renames are split into a delete + add

---

## Layer 4 — SyncEngine

`SyncEngine` is the public entry point. It holds a list of parsers and a map of syncers, and wires everything together.

**`addSource(url)`**:

1. Find a parser that can handle the URL
2. Create a folder in `appFolder`
3. Write the initial `SourceConfig` to `.source/source.json`
4. Call `_performSync`

**`syncSource(sourceFolder)`**:

1. Calls `_performSync`

**`_performSync(sourceFolder)`**:

1. Set status to `syncing`
2. Read `SourceConfig`
3. Call the appropriate syncer to get deltas
4. Apply deltas with `FileWriter`
5. Mark sync complete (or set status to `error` on failure)
6. Return `SyncResult`
