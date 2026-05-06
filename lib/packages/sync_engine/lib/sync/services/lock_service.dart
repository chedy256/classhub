import 'dart:convert';
import 'dart:io';

class LockService {
  static const String _lockSuffix = '.sync.lock';

  String _lockPath(Directory parentDir, String sourceFolderName) {
    return '${parentDir.path}/.$sourceFolderName$_lockSuffix';
  }

  bool hasStale(Directory parentDir, String sourceFolderName, Duration staleness) {
    final lockFile = File(_lockPath(parentDir, sourceFolderName));
    if (!lockFile.existsSync()) return false;
    try {
      final json = jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
      final lockedAt = DateTime.parse(json['locked_at'] as String);
      final age = DateTime.now().difference(lockedAt);
      return age >= staleness;
    } catch (_) {
      return true;
    }
  }

  bool exists(Directory parentDir, String sourceFolderName) {
    return File(_lockPath(parentDir, sourceFolderName)).existsSync();
  }

  Future<void> deleteLock(Directory parentDir, String sourceFolderName) async {
    final lockFile = File(_lockPath(parentDir, sourceFolderName));
    if (await lockFile.exists()) {
      await lockFile.delete();
    }
  }

  bool tryAcquire(Directory parentDir, String sourceFolderName, Duration staleness) {
    final lockFile = File(_lockPath(parentDir, sourceFolderName));
    if (lockFile.existsSync()) {
      try {
        final json = jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
        final lockedAt = DateTime.parse(json['locked_at'] as String);
        final age = DateTime.now().difference(lockedAt);
        if (age < staleness) return false;
        lockFile.deleteSync();
      } catch (_) {
        lockFile.deleteSync();
      }
    }
    _writeLock(parentDir, sourceFolderName);
    return true;
  }

  void refresh(Directory parentDir, String sourceFolderName) {
    try {
      _writeLock(parentDir, sourceFolderName);
    } catch (_) {}
  }

  Future<void> release(Directory parentDir, String sourceFolderName) async {
    final lockFile = File(_lockPath(parentDir, sourceFolderName));
    if (await lockFile.exists()) {
      await lockFile.delete();
    }
  }

  void _writeLock(Directory parentDir, String sourceFolderName) {
    final lockFile = File(_lockPath(parentDir, sourceFolderName));
    final json = jsonEncode({'locked_at': DateTime.now().toUtc().toIso8601String()});
    lockFile.writeAsStringSync(json, flush: true);
  }
}
