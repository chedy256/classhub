## **1. Core Components**

### **`SyncEngine`**

- **Purpose**: Orchestrates the sync process.
- **Input**: `appFolder` (root directory for all sources).
- **Methods**:
  - `addSource(url)`: Adds a new source, creates its folder, and performs the initial sync.
  - `syncSource(sourceFolder)`: Syncs an existing source.

---

### **`SourceParser` (Interface)**

- **Purpose**: Parses a source URL and returns a `SourceConfig`.
- **Methods**:
  - `canParse(url)`: Checks if the parser can handle the URL.
  - `parseUrlToSourceConfig(url)`: Parses the URL and returns a `SourceConfig`.
  - `getSourceFolderName(url)`: Extracts the folder name from the URL.

---

### **`SourceSyncer` (Interface)**

- **Purpose**: Fetches file deltas for a source.
- **Method**:
  - `getDeltas(config)`: Returns `SyncerOutput` (list of `FileDelta` and `checkpoint`).

---

### **`SourceConfig`**

- **Purpose**: Represents the configuration for a source.
- **Fields**:
  - `type`: `SourceType` (github, drive, classroom).
  - `url`: The source URL.
  - `manifestVersion`: Version of the manifest.
  - `syncStatus`: Current sync status (`idle`, `syncing`, `error`, `never`).
  - `lastSyncedAt`: Timestamp of the last successful sync.
  - `checkpoint`: Abstract identifier for the last sync point (e.g., commit SHA for GitHub).
  - `defaultBranch`: Resolved branch name for the source.

---

### **`FileDelta`**

- **Purpose**: Represents a file change (add, update, delete).
- **Fields**:
  - `relativePath`: Path of the file.
  - `downloadUrl`: URL to download the file (null for deletes).
  - `type`: `DeltaType` (add, update, delete).

---

### **`SourceStore`**

- **Purpose**: Manages reading/writing `source.json`.
- **Methods**:
  - `write(sourceFolder, config)`: Writes the config to disk.
  - `read(sourceFolder)`: Reads the config from disk.
  - `updateStatus(sourceFolder, status)`: Updates the sync status.
  - `markSyncComplete(sourceFolder, checkpoint)`: Marks sync as complete, updating `lastSyncedAt` and `checkpoint`.

---

### **`FileWriter`**

- **Purpose**: Applies `FileDelta` changes to disk.
- **Method**:
  - `apply(targetFolder, deltas)`: Applies deltas and returns `FileWriterResult`.

---

### **`SyncResult`**

- **Purpose**: Represents the result of a sync operation.
- **Fields**:
  - `success`: Whether the sync succeeded.
  - `filesAdded`, `filesUpdated`, `filesDeleted`: Counts of changes.
  - `error`: Error message (if any).
  - `syncedAt`: Timestamp of the sync.
  - `totalChanges`: Helper to sum all changes.

---

## **2. Flow for `addSource`**

1. **Parse URL**: Use `SourceParser` to parse the URL and create `SourceConfig`.
2. **Create Folder**: Create a folder for the source in `appFolder`.
3. **Write Config**: Write the `SourceConfig` to `.source/source.json`.
4. **Sync**: Call `syncSource(sourceFolder)` to perform the sync.

---

## **3. Flow for `syncSource`**

1. **Read Config**: Read `SourceConfig` from `.source/source.json`.
2. **Set Syncing**: Update status to `syncing`.
3. **Get Deltas**: Use `SourceSyncer` to fetch file deltas.
4. **Apply Deltas**: Use `FileWriter` to apply deltas to disk.
5. **Mark Complete**: Update status to `idle`, set `lastSyncedAt` and `checkpoint`.

---

## **4. Key Abstractions**

- **`checkpoint`**: Abstract identifier for the last sync point (not just GitHub commit SHA).
- **`defaultBranch`**: Resolved branch name, stored to avoid re-fetching repo metadata.
- **Encapsulation**: Each parser/syncer handles its own logic; `SyncEngine` is a dumb orchestrator.

---

## **5. What I Will Implement Next**

-[x] **GitHub Parser**: Implement `GithubSourceParser` with `canParse`, `parseUrlToSourceConfig`, and `getSourceFolderName`.

-[x] **GitHub Syncer**: Implement `GithubSyncer` with `getDeltas` to fetch file deltas from GitHub.

---
