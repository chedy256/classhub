# sync_engine

A Dart package for pulling and syncing course material from remote sources (GitHub, Google Drive, Google Classroom) to local storage. Built as the core of the [ClassHub](https://github.com/ClassHubTeam/classhub) mobile app.

---

## What it does

- Fetches file changes from a remote source and applies them to a local folder
- Tracks sync state per source (last synced commit, sync status, timestamps)
- Supports full clone on first sync and incremental diff on subsequent syncs
- Handles add, update, delete, and rename file operations

---

## Supported sources

| Source                | Status       |
| --------------------- | ------------ |
| GitHub (public repos) | -[x] Done    |
| Google Drive          | -[x] Done    |
| Google Classroom      | -[ ] Planned |

---

## Architecture

The package is organized in 4 layers. Each layer only depends on the one below it.

```text
┌─────────────────────────────────┐
│  4. SyncEngine (orchestrator)   │
├─────────────────────────────────┤
│  3. Source Parsers & Syncers    │
├─────────────────────────────────┤
│  2. Services (store, writer)    │
├─────────────────────────────────┤
│  1. Models                      │
└─────────────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

---

## Usage

```dart
final engine = SyncEngine(appFolder: Directory('/path/to/app'));

// Add a new source (parses URL, creates folder, runs initial sync)
final result = await engine.addSource('https://github.com/owner/repo');

// Sync an existing source
final sourceFolder = Directory('/path/to/app/repo');
final result = await engine.syncSource(sourceFolder);

print(result.success);       // true
print(result.filesAdded);    // files added this sync
print(result.totalChanges);  // total files changed
```

Each source folder gets a `.source/source.json` file that tracks its configuration and sync state.

---

## Project structure

```text
lib/
  sync_engine.dart
  src/
    models/
      file_delta.dart
      source_config.dart
      sync_result.dart
      syncer_output.dart
    services/
      file_writer.dart
      source_store.dart
      http/
        http_client.dart
    sync/
      sync_engine.dart
      source_parser.dart
      source_syncer.dart
    sources/
      github/
        github_parser.dart
        github_syncer.dart
        github_client.dart
      drive/
        drive_parser.dart
        drive_syncer.dart
      classroom/
        classroom_parser.dart
        classroom_syncer.dart
  utils/
    logger.dart
    path_utils.dart
```

---

## Running tests

```bash
dart test
```

Integration tests make real GitHub API calls and require network access.
