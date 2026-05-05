import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

class DirectoryWatcher with WidgetsBindingObserver {
  final String path;
  final VoidCallback onChanged;
  final Duration interval;
  Timer? _timer;
  DateTime? _lastModTime;
  final Map<String, DateTime> _childModTimes = {};

  DirectoryWatcher({
    required this.path,
    required this.onChanged,
    this.interval = const Duration(seconds: 1),
  });

  void start() {
    stop();
    _childModTimes.clear();
    WidgetsBinding.instance.addObserver(this);
    try {
      _lastModTime = Directory(path).statSync().modified;
      _cacheChildModTimes();
    } catch (_) {}
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _cacheChildModTimes() {
    try {
      for (final entry in Directory(path).listSync(followLinks: false)) {
        if (entry is Directory) {
          _childModTimes[entry.path] = entry.statSync().modified;
        }
      }
    } catch (_) {}
  }

  void _poll() {
    try {
      final dir = Directory(path);

      final now = dir.statSync().modified;
      if (now != _lastModTime) {
        _lastModTime = now;
        _cacheChildModTimes();
        onChanged();
        return;
      }

      final currentEntries = dir.listSync(followLinks: false);
      for (final entry in currentEntries) {
        if (entry is Directory) {
          final childMod = entry.statSync().modified;
          final prevMod = _childModTimes[entry.path];
          if (prevMod != null && childMod != prevMod) {
            _childModTimes[entry.path] = childMod;
            onChanged();
            return;
          }
          if (prevMod == null) {
            _childModTimes[entry.path] = childMod;
            onChanged();
            return;
          }
        }
      }

      _childModTimes.removeWhere(
        (childPath, _) => !currentEntries.any((e) => e.path == childPath),
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) start();
    if (state == AppLifecycleState.paused) stop();
  }
}
