# Changelog

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
