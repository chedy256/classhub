import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/trash_item.dart';

class TrashService {
  static const String _trashDirName = '.classhub_trash';
  static const String _manifestFileName = '.trash_manifest.json';

  /// Returns the trash directory path for a given root
  String _trashDirPath(String rootPath) => p.join(rootPath, _trashDirName);

  String _manifestPath(String rootPath) =>
      p.join(_trashDirPath(rootPath), _manifestFileName);

  /// Ensures the trash directory exists
  void _ensureTrashDir(String rootPath) {
    final dir = Directory(_trashDirPath(rootPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Load the manifest (list of trash items)
  List<TrashItem> loadManifest(String rootPath) {
    try {
      final trashDir = Directory(_trashDirPath(rootPath));
      if (!trashDir.existsSync()) return [];
      final file = File(_manifestPath(rootPath));
      if (!file.existsSync()) return [];
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return [];
      return TrashItem.decodeList(content);
    } catch (_) {
      return [];
    }
  }

  /// Save the manifest
  void _saveManifest(String rootPath, List<TrashItem> items) {
    _ensureTrashDir(rootPath);
    final file = File(_manifestPath(rootPath));
    file.writeAsStringSync(TrashItem.encodeList(items));
  }

  /// Move a file or folder to trash
  void moveToTrash(String rootPath, FileSystemEntity entity) {
    _ensureTrashDir(rootPath);

    final name = p.basename(entity.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final trashName = '${timestamp}_$name';
    final trashPath = p.join(_trashDirPath(rootPath), trashName);

    entity.renameSync(trashPath);

    final items = loadManifest(rootPath);
    items.add(
      TrashItem(
        originalPath: entity.path,
        trashPath: trashPath,
        isDirectory: entity is Directory,
        deletedAt: DateTime.now(),
      ),
    );
    _saveManifest(rootPath, items);
  }

  /// Restore a single item from trash to its original location
  bool restoreItem(String rootPath, TrashItem item) {
    final entity = item.isDirectory
        ? Directory(item.trashPath)
        : File(item.trashPath) as FileSystemEntity;

    if (!entity.existsSync()) return false;

    // Ensure the parent directory exists
    final parentDir = Directory(p.dirname(item.originalPath));
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    entity.renameSync(item.originalPath);

    final items = loadManifest(rootPath);
    items.removeWhere((i) => i.trashPath == item.trashPath);
    _saveManifest(rootPath, items);
    return true;
  }

  /// Restore multiple items
  void restoreItems(String rootPath, List<TrashItem> toRestore) {
    for (final item in toRestore) {
      restoreItem(rootPath, item);
    }
  }

  /// Permanently delete a single item
  void permanentlyDelete(String rootPath, TrashItem item) {
    final entity = item.isDirectory
        ? Directory(item.trashPath)
        : File(item.trashPath) as FileSystemEntity;

    if (entity.existsSync()) {
      entity.deleteSync(recursive: true);
    }

    final items = loadManifest(rootPath);
    items.removeWhere((i) => i.trashPath == item.trashPath);
    _saveManifest(rootPath, items);
  }

  /// Permanently delete multiple items
  void permanentlyDeleteItems(String rootPath, List<TrashItem> toDelete) {
    for (final item in toDelete) {
      final entity = item.isDirectory
          ? Directory(item.trashPath)
          : File(item.trashPath) as FileSystemEntity;
      if (entity.existsSync()) {
        entity.deleteSync(recursive: true);
      }
    }

    final trashPaths = toDelete.map((e) => e.trashPath).toSet();
    final items = loadManifest(rootPath);
    items.removeWhere((i) => trashPaths.contains(i.trashPath));
    _saveManifest(rootPath, items);
  }

  /// Purge all expired items (older than 30 days)
  void purgeExpired(String rootPath) {
    final trashDir = Directory(_trashDirPath(rootPath));
    if (!trashDir.existsSync()) return;
    final items = loadManifest(rootPath);
    final expired = items.where((i) => i.isExpired).toList();
    if (expired.isEmpty) return;
    permanentlyDeleteItems(rootPath, expired);
  }

  /// Empty the entire trash
  void emptyTrash(String rootPath) {
    final items = loadManifest(rootPath);
    permanentlyDeleteItems(rootPath, items);
  }

  /// Get file size in bytes (for display)
  int entitySize(TrashItem item) {
    try {
      if (item.isDirectory) {
        return _dirSize(Directory(item.trashPath));
      }
      final file = File(item.trashPath);
      if (!file.existsSync()) return 0;
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  int _dirSize(Directory dir) {
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    } catch (_) {}
    return total;
  }
}
