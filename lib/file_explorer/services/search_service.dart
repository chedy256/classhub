import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class SearchService {
  static const int maxRecentSearches = 8;
  static const String _fileName = '.classhub_recent_searches.json';

  String _filePath(String rootPath) => p.join(rootPath, _fileName);

  List<String> loadRecentSearches(String rootPath) {
    final file = File(_filePath(rootPath));
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(file.readAsStringSync());
      return List<String>.from(json as List);
    } catch (_) {
      return [];
    }
  }

  void addRecentSearch(String rootPath, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final recent = loadRecentSearches(rootPath);
    recent.remove(trimmed);
    recent.insert(0, trimmed);
    if (recent.length > maxRecentSearches) {
      recent.removeRange(maxRecentSearches, recent.length);
    }
    File(_filePath(rootPath)).writeAsStringSync(jsonEncode(recent));
  }

  void removeRecentSearch(String rootPath, String query) {
    final recent = loadRecentSearches(rootPath);
    recent.remove(query);
    File(_filePath(rootPath)).writeAsStringSync(jsonEncode(recent));
  }

  void clearRecentSearches(String rootPath) {
    final file = File(_filePath(rootPath));
    if (file.existsSync()) file.deleteSync();
  }

  /// Recursively search all entries under [rootPath], filtering hidden dirs.
  List<FileSystemEntity> search(
    String rootPath,
    String query,
    SearchFilter filter,
  ) {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return [];
    final lowerQuery = query.toLowerCase();
    final results = <FileSystemEntity>[];
    _searchRecursive(dir, lowerQuery, filter, results);
    return results;
  }

  void _searchRecursive(
    Directory dir,
    String lowerQuery,
    SearchFilter filter,
    List<FileSystemEntity> results,
  ) {
    try {
      for (final entity in dir.listSync()) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final matches = name.toLowerCase().contains(lowerQuery);
        if (entity is Directory) {
          if (matches && filter != SearchFilter.files) {
            results.add(entity);
          }
          _searchRecursive(entity, lowerQuery, filter, results);
        } else if (entity is File) {
          if (matches && filter != SearchFilter.folders) {
            results.add(entity);
          }
        }
      }
    } catch (_) {}
  }
}

enum SearchFilter { all, folders, files }
