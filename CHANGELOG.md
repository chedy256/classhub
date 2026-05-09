# Changelog

## v1.2.2 - 2026-05-09

### Changed

- Switched to Material Design icon fonts for source type icons
- File-type-aware icons for regular files (PDF, video, image, etc.)

### Fixed

- Files showing folder icon in main screen list
- Empty named parameter syntax in SyncEngine

---

## v1.2.1 - 2026-05-06

### Added

- Source type icons on synced folders (GitHub, Drive, Classroom)

---

## v1.2.0 - 2026-05-06

### Added

- Auto-resume interrupted syncs on app launch with snackbar notification
- Update check on startup (6-hour rate limit) with badge on menu and About screen
- GitHub token setting in Settings screen to avoid API rate limits
- Parallel source adding when using ClassHub URLs
- Folder name in sync completion snackbar

### Changed

- Sync engine uses GitHub token from settings for all API calls
- Update checker respects GitHub token for higher rate limits

### Fixed

- Independent progress tracking for concurrent syncs (no cross-contamination)
- Unified snackbar theme color across all screens
- Sync snackbar shows source folder name for clarity

---

## v1.1.0 - 2026-05-06

### Added

- Resumable sync downloads with crash recovery via sync queue
- Live progress tracking in folder cards, app bars, and Properties dialog
- Android foreground service for background sync with notification
- `getSourceFolderName()` utility in sync_engine for all source types

### Changed

- Direct sync into source folder (removed temp folder approach)
- Sync now shows progress percentage and current file name

### Fixed

- Repo name display when adding sources via ClassHub URL

### Internal

- sync_engine: queue model, lock service, file writer callbacks
- sync_engine: 70 tests passing including resume-from-crash tests
