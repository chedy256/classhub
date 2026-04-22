import 'dart:io';

import 'package:sync_engine/sync_engine.dart';

void main() async {
  const repoUrl = "https://github.com/octocat/Hello-World";
  syncEngine = SyncEngine(
    appFolder: Directory("/tmp/classhub_sync_engine_test"),
  );
}
