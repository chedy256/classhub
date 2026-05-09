import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sync_engine/sync_engine.dart';

class FileExplorerService {
  final SourceStore _sourceStore = SourceStore();

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
    return _sourceStore.existsSync(Directory(path));
  }

  SourceConfig? getSourceConfig(String path) {
    return _sourceStore.readSync(Directory(path));
  }

  String? formatLastSynced(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
    final config = getSourceConfig(path);
    return config?.url;
  }

  List<Directory> getSources(String rootPath) {
    final entries = loadEntries(rootPath);
    return entries
        .whereType<Directory>()
        .where((d) => isSyncedSource(d.path))
        .toList();
  }

  Future<List<XFile>> zipDirectories(List<Directory> dirs) async {
    if (dirs.isEmpty) return [];
    final tempDir = await getTemporaryDirectory();
    final results = <XFile>[];
    for (final dir in dirs) {
      final zipPath = '${tempDir.path}/${p.basename(dir.path)}.zip';
      try {
        final archive = Archive();
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: dir.path);
            final bytes = entity.readAsBytesSync();
            archive.addFile(ArchiveFile(rel, bytes.length, bytes));
          }
        }
        final data = ZipEncoder().encode(archive);
        if (data != null) {
          await File(zipPath).writeAsBytes(data);
          results.add(XFile(zipPath));
        }
      } catch (_) {}
    }
    Future.delayed(const Duration(seconds: 30), () {
      for (final xf in results) {
        File(xf.path).deleteSync();
      }
    });
    return results;
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
