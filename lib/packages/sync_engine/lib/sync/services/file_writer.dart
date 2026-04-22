// lib/sync/services/file_writer.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/file_delta.dart';

/// The result of applying a batch of [FileDelta]s to disk.
class FileWriterResult {
  final int filesAdded;
  final int filesUpdated;
  final int filesDeleted;
  final List<String> errors; // relativePaths that failed

  const FileWriterResult({
    this.filesAdded = 0,
    this.filesUpdated = 0,
    this.filesDeleted = 0,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalChanges => filesAdded + filesUpdated + filesDeleted;
}

/// Applies a [List<FileDelta>] to a local folder on disk.
///
/// Responsibilities:
///   - add/update: download content from [FileDelta.downloadUrl] and write
///     it to [FileDelta.relativePath] inside [targetFolder], creating any
///     intermediate directories as needed.
///   - delete: remove the file at [FileDelta.relativePath] if it exists.
///     Silently skips files that are already gone.
///
/// This class knows nothing about GitHub, Drive, or source.json.
/// It only speaks [FileDelta].
class FileWriter {
  final http.Client _httpClient;

  /// [httpClient] is injectable so tests can pass a mock.
  /// Defaults to a real [http.Client] if omitted.
  FileWriter({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Applies [deltas] to [targetFolder] and returns a [FileWriterResult].
  ///
  /// Processes deltas sequentially. On a per-file error the failure is
  /// recorded in [FileWriterResult.errors] and processing continues —
  /// a single bad download does not abort the whole sync.
  Future<FileWriterResult> apply(
    Directory targetFolder,
    List<FileDelta> deltas,
  ) async {
    int added = 0;
    int updated = 0;
    int deleted = 0;
    final errors = <String>[];

    for (final delta in deltas) {
      try {
        switch (delta.type) {
          case DeltaType.add:
            await _writeFile(
              targetFolder,
              delta.relativePath,
              delta.downloadUrl!,
            );
            added++;
          case DeltaType.update:
            await _writeFile(
              targetFolder,
              delta.relativePath,
              delta.downloadUrl!,
            );
            updated++;
          case DeltaType.delete:
            await _deleteFile(targetFolder, delta.relativePath);
            deleted++;
        }
      } catch (e) {
        // Catch both Exception and Error (e.g. ArgumentError from path guard).
        // Record the failure and continue — a partial sync is better than an
        // aborted one. The engine can decide what to do with errors.
        errors.add('${delta.relativePath}: $e');
      }
    }

    return FileWriterResult(
      filesAdded: added,
      filesUpdated: updated,
      filesDeleted: deleted,
      errors: errors,
    );
  }

  // ── private ──────────────────────────────────────────────────────────────────

  Future<void> _writeFile(
    Directory targetFolder,
    String relativePath,
    String downloadUrl,
  ) async {
    final file = _resolveFile(targetFolder, relativePath);

    // Create parent directories (e.g. "assignments/week1/") if they don't exist
    await file.parent.create(recursive: true);

    final response = await _httpClient.get(Uri.parse(downloadUrl));

    if (response.statusCode != 200) {
      throw HttpException(
        'Download failed for $relativePath — '
        'GET $downloadUrl returned ${response.statusCode}',
      );
    }

    await file.writeAsBytes(response.bodyBytes);
  }

  Future<void> _deleteFile(Directory targetFolder, String relativePath) async {
    final file = _resolveFile(targetFolder, relativePath);

    if (await file.exists()) {
      await file.delete();
    }
    // Silently ignore missing files — idempotent by design.
    // If the file is already gone, the desired end-state is achieved.
  }

  /// Resolves a [relativePath] against [targetFolder], guarding against
  /// path-traversal attacks (e.g. relativePath = "../../etc/passwd").
  File _resolveFile(Directory targetFolder, String relativePath) {
    // Use absolute paths so ".." segments are collapsed before comparison
    final base = targetFolder.absolute.path;
    final resolved = File('$base/$relativePath').absolute;

    if (!resolved.path.startsWith(base)) {
      throw ArgumentError(
        'Path traversal detected: "$relativePath" resolves outside target folder.',
      );
    }

    return resolved;
  }
}
