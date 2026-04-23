# Classhub

Flutter app for syncing files from GitHub/Classroom/etc to local storage.

## Dev Commands

```bash
flutter pub get          # Install dependencies
flutter analyze       # Lint + typecheck
flutter test           # Run tests (root + sync_engine package)
flutter build apk --debug   # Build debug APK
```

For single test:
```bash
# App tests:
flutter test test/widget_test.dart
# sync_engine package (run from package dir):
cd lib/packages/sync_engine && dart test test/sync/models/source_config_test.dart
```

## Architecture

- **Entry**: `lib/main.dart` - `ClasshubApp(isSetupComplete, rootPath)`
- **Modules**: `lib/{feature}/{screens,services,models}/`
- **sync_engine**: `lib/packages/sync_engine/` - local Dart package, own pubspec.yaml
- **Test packages**: App uses `flutter_test`, sync_engine uses `test` (package:test)

## Release

Push tag `v*` to trigger `.github/workflows/release.yml` - builds APK, publishes to `titanknis/classhub-releases`.

## Dev Environment

Nix flake (`flake.nix`) provides Flutter + Android SDK. Run `nix develop` to enter.