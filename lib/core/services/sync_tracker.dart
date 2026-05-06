import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sync_engine/sync_engine.dart';

import 'sync_foreground_service.dart';

class SyncTracker {
  final SyncForegroundService _nativeService = SyncForegroundService();
  Timer? _throttleTimer;
  SyncProgress? _latestProgress;
  String? _activeSourcePath;
  bool _isTracking = false;

  final ValueNotifier<Map<String, SyncProgress>> progress = ValueNotifier({});

  SyncProgressCallback start(String sourcePath) {
    _activeSourcePath = sourcePath;
    _isTracking = true;
    _latestProgress = null;
    progress.value = {};
    final sourceName = p.basename(sourcePath);
    _nativeService.start(sourceName, 0);
    return _onProgress;
  }

  void stop() {
    _isTracking = false;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _nativeService.stop();
  }

  void setProgress(String sourcePath, SyncProgress p) {
    final updated = Map<String, SyncProgress>.from(progress.value);
    updated[sourcePath] = p;
    progress.value = updated;
  }

  void clearProgress(String sourcePath) {
    if (progress.value.containsKey(sourcePath)) {
      final updated = Map<String, SyncProgress>.from(progress.value);
      updated.remove(sourcePath);
      progress.value = updated;
    }
  }

  void clearAll() {
    progress.value = {};
  }

  void _onProgress(SyncProgress progress) {
    _latestProgress = progress;

    final sourcePath = _activeSourcePath;
    if (sourcePath != null) {
      setProgress(sourcePath, progress);
    }

    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(seconds: 1), () {
      _flushProgress();
    });
  }

  void _flushProgress() {
    final p = _latestProgress;
    if (p == null || !_isTracking) return;

    final percent = p.totalBytes != null
        ? ((p.byteProgress ?? 0) * 100).toInt()
        : (p.progress * 100).toInt();

    _nativeService.update(
      percent: percent,
      currentFile: p.currentFile ?? '',
      completed: p.completed,
      total: p.total,
    );
  }
}
