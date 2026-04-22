# **Sync Engine Documentation**

Let’s think in **layers**, bottom to top. We build lower layers first, then each layer above only talks to the layer beneath it.

---

## **Project Structure**

```
.
├── README.md
├── sync
│   ├── models/
│   │   ├── file_delta.dart
│   │   ├── source_config.dart
│   │   ├── sync_result.dart
│   │   └── syncer_output.dart
│   ├── services/
│   │   ├── file_writer.dart
│   │   └── source_store.dart
│   └── sources/
│       ├── classroom/
│       │   └── classroom_syncer.dart
│       ├── drive/
│       │   └── drive_syncer.dart
│       ├── github/
│       │   ├── http_client.dart
│       │   ├── parser.dart
│       │   └── syncer.dart
│       ├── source_parser.dart
│       └── source_syncer.dart
└── sync_engine.dart
```

---

## **The 4 Layers**

```
┌─────────────────────────────────┐
│  4. Sync Engine (orchestrator)  │  ← what the UI calls
├─────────────────────────────────┤
│  3. Source Syncers & Parsers    │  ← GitHub / Drive / Classroom
├─────────────────────────────────┤
│  2. Shared Services             │  ← source.json I/O, file writer
├─────────────────────────────────┤
│  1. Models                      │  ← pure data, no logic
└─────────────────────────────────┘
```

Each layer only knows about the layer below it. The orchestrator doesn't touch the file system directly. The syncers and parsers don't know about `source.json`. Etc.

---

## **Layer 1 — Models**

Pure Dart classes. No methods, no I/O. Just data and `fromJson`/`toJson`.

### **Files**

- `file_delta.dart`: Represents a file change (add, update, delete).
- `source_config.dart`: Represents the configuration for a source.
- `sync_result.dart`: Represents the result of a sync operation.
- `syncer_output.dart`: Contains `FileDelta` list and `checkpoint`.

### **Key Contract: `FileDelta`**

```dart
enum DeltaType { add, update, delete }

class FileDelta {
  final String relativePath;
  final String? downloadUrl; // null for deletes
  final DeltaType type;
}
```

`FileDelta` is the key shared contract between syncers and the file writer.

---

## **Layer 2 — Shared Services**

Three focused services. Each does one job.

### **Files**

- `source_store.dart`: All reads/writes to `source.json`.
- `file_writer.dart`: Applies `List<FileDelta>` to disk.
- `http_client.dart`: Thin wrapper for HTTP requests.

### **Responsibilities**

- **`source_store.dart`**: Reads/writes `.source/source.json`, updates sync status, and marks sync completion.
- **`file_writer.dart`**: Applies deltas to disk, creating/updating/deleting files.
- **`http_client.dart`**: Handles auth headers and HTTP requests for syncers.

---

## **Layer 3 — Source Syncers & Parsers**

Each source type has its own parser and syncer.

### **Files**

- `source_syncer.dart`: Abstract interface for syncers.
- `source_parser.dart`: Abstract interface for parsers.
- `github/`, `drive/`, `classroom/`: Source-specific implementations.

### **Key Contracts**

- **Parser**:
  ```dart
  abstract class SourceParser {
    SourceType get sourceType;
    bool canParse(String url);
    Future<SourceConfig> parseUrlToSourceConfig(String url);
    String getSourceFolderName(String url);
  }
  ```
- **Syncer**:
  ```dart
  abstract class SourceSyncer {
    Future<SyncerOutput> getDeltas(SourceConfig config);
  }
  ```

### **Responsibilities**

- **Parser**: Extracts source-specific info (e.g., owner/repo/branch for GitHub) and creates `SourceConfig`.
- **Syncer**: Fetches file deltas using source-specific logic (e.g., GitHub API).

---

## **Layer 4 — Sync Engine**

### **File**

- `sync_engine.dart`

### **Responsibilities**

The `SyncEngine` orchestrates the sync process:

1. **Add a Source**:
   - Parse the URL using the appropriate parser.
   - Create a source folder in the app directory.
   - Write the initial `SourceConfig` to `.source/source.json`.
   - Perform the initial sync.

2. **Sync an Existing Source**:
   - Read `SourceConfig` from `.source/source.json`.
   - Set status to `syncing`.
   - Fetch deltas using the appropriate syncer.
   - Apply deltas using `FileWriter`.
   - Mark sync as complete (update `lastSyncedAt` and `checkpoint`).

---

## **What We Will Build First**

```
Step 1 → Models (no dependencies, easy to get right)
Step 2 → source_store.dart & file_writer.dart (no network, testable immediately)
Step 3 → http_client.dart & source_parser.dart (thin, no business logic)
Step 4 → source_syncer.dart & source-specific syncers (e.g., github_syncer.dart)
Step 5 → sync_engine.dart (wire it all together)
```

Drive and Classroom syncers/parsers are just new `Step 4` implementations.

---

**Next Steps**: Implement `GithubParser` and `GithubSyncer` to complete the GitHub integration.
