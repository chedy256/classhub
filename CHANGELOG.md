# Changelog

## v1.2.6 - 2026-05-11

### Fixed

- Default directory now created on disk during onboarding after storage permission is granted, preventing infinite onboarding loop on newly installed devices

---

## v1.2.5 - 2026-05-10

### Fixed

- Theme toggle not working on first app launch (missing callback in onboarding flow)
- External storage path now resolved dynamically instead of hardcoded
- Removed 500ms delay before showing What's New dialog

### Added

- README, LICENSE, and contributor credits

---

## v1.2.4 - 2026-05-10

### Added

- "What's New" bottom sheet with rendered changelog on update
- Download progress bar in About screen
- Version tracking for update detection

### Fixed

- Concurrent APK download guard
- Orphaned temp ZIP files cleaned on startup
- APK removed after install
- Don't reuse cached APK by size

### Internal

- `flutter_markdown` dependency
- `ClasshubStorageService.lastSeenVersion`
- `changelog_service.dart`

---

## v1.2.3 - 2026-05-09

### Added

- Share folders as zip archives from context menu and multi-selection
- Dynamic share button label ("Share files" / "Share sources" / "Share content") based on selection

### Changed

- Swapped multi-select bottom bar: "Move to trash" on left, "Share" on right
- Folder sharing now zips directories alongside files when mixed selection
- Non-source folders fall back to zip sharing instead of showing empty URL error
- Rename dialog pre-fills current name in the input field

### Internal

- Added `archive: ^4.0.9` dependency for zip creation
- Added `zipDirectories()` to `FileExplorerService` with 30s temp cleanup

---

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
