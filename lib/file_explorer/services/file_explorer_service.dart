import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileExplorerService {
  List<FileSystemEntity> loadEntries(String rootPath) {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) {
      return [];
    }

    final all = dir.listSync()
      ..removeWhere((e) => p.basename(e.path).startsWith('.'))
      ..sort((a, b) {
        // Folders first, then files
        final aIsDir = a is Directory ? 0 : 1;
        final bIsDir = b is Directory ? 0 : 1;
        if (aIsDir != bIsDir) return aIsDir.compareTo(bIsDir);
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
    return all;
  }

  bool isSyncedSource(String path) {
    return File(p.join(path, '.source', 'source.json')).existsSync();
  }

  bool isInsideSource(String path, String rootPath) {
    if (isSyncedSource(path)) return true;
    String? current = p.dirname(path);
    while (current != null && current != rootPath && current != p.dirname(current)) {
      if (isSyncedSource(current)) return true;
      current = p.dirname(current);
    }
    return false;
  }

  String? getSourceUrl(String path) {
    final sourceFile = File(p.join(path, '.source', 'source.json'));
    if (!sourceFile.existsSync()) return null;
    try {
      final json = sourceFile.readAsStringSync();
      final data = _parseJson(json);
      return data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  dynamic _parseJson(String json) {
    return const JsonDecoder().convert(json);
  }

  List<Directory> getSources(String rootPath) {
    final entries = loadEntries(rootPath);
    return entries
        .whereType<Directory>()
        .where((d) => isSyncedSource(d.path))
        .toList();
  }

  List<FileSystemEntity> loadFolderContents(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return [];
    final all = dir.listSync()
      ..removeWhere((e) => p.basename(e.path).startsWith('.'))
      ..sort((a, b) {
        final aIsDir = a is Directory ? 0 : 1;
        final bIsDir = b is Directory ? 0 : 1;
        if (aIsDir != bIsDir) return aIsDir.compareTo(bIsDir);
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
    return all;
  }

  void createFolder(String rootPath, String folderName) {
    if (folderName.trim().isEmpty) return;

    final sanitized = folderName.trim().replaceAll(RegExp(r'[/\\]'), '_');
    final newDir = Directory(p.join(rootPath, sanitized));
    if (!newDir.existsSync()) {
      newDir.createSync();
    }
  }

  void copyFolderTo(String destParent, String srcDirPath) {
    final folderName = p.basename(srcDirPath);
    final destDir = Directory(p.join(destParent, folderName));
    _copyDirectory(Directory(srcDirPath), destDir);
  }

  void uploadFilesToFolder(String folderPath, List<String> filePaths) {
    for (final srcPath in filePaths) {
      final src = File(srcPath);
      final dest = File(p.join(folderPath, p.basename(srcPath)));
      src.copySync(dest.path);
    }
  }

  void renameEntity(FileSystemEntity entity, String newName) {
    final parentDir = p.dirname(entity.path);
    final newPath = p.join(parentDir, newName);
    entity.renameSync(newPath);
  }

  int countChildren(FileSystemEntity entity) {
    if (entity is Directory) {
      try {
        return entity.listSync()
            .where((e) => !p.basename(e.path).startsWith('.'))
            .length;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  Future<int> getFolderSize(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return 0;

    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += entity.lengthSync();
      }
    }
    return total;
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String entitySubtitle(FileSystemEntity entity) {
    if (entity is Directory) {
      final count = countChildren(entity);
      return '$count items';
    }
    if (entity is File) {
      try {
        return formatSize(entity.lengthSync());
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  void _copyDirectory(Directory source, Directory destination) {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    for (final entity in source.listSync()) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
