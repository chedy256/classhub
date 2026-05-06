import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sync_engine/sync_engine.dart';
import '../../core/services/classhub_storage_service.dart';
import '../../core/services/sync_tracker.dart';

String syncProgressText(SyncProgress p) {
  final pct = p.totalBytes != null
      ? ((p.byteProgress ?? 0) * 100).toInt()
      : (p.progress * 100).toInt();
  final file = p.currentFile != null ? ' — ${p.currentFile}' : '';
  return '$pct%$file';
}

typedef SyncResultCallback = void Function(SyncResult result);

Future<void> performSync({
  required Directory sourceDir,
  required String rootPath,
  required SyncTracker? syncTracker,
  required BuildContext context,
  VoidCallback? onBeforeSync,
  VoidCallback? onAfterSync,
  SyncResultCallback? onSuccess,
  String? customFolderName,
}) async {
  final sourcePath = sourceDir.path;
  final trackerCallback = syncTracker?.start(sourcePath) ?? (_) {};

  onBeforeSync?.call();

  final syncEngine = SyncEngine(
    appFolder: Directory(rootPath),
    githubToken: await ClasshubStorageService.getGithubToken(),
    onProgress: (progress) {
      if (context.mounted) trackerCallback(progress);
    },
  );
  final result = await syncEngine.syncSource(sourceDir);
  syncTracker?.stop();
  syncTracker?.clearProgress(sourcePath);
  if (!context.mounted) return;

  onAfterSync?.call();

  if (result.success) {
    onSuccess?.call(result);
  }
}
