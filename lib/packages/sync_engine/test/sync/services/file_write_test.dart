// test/sync/services/file_writer_test.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart'; // provides MockClient
import 'package:test/test.dart';
import 'package:sync_engine/sync/models/file_delta.dart';
import 'package:sync_engine/sync/services/file_writer.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [MockClient] that always returns [body] with [statusCode].
http.Client _mockHttp({String body = 'file content', int statusCode = 200}) {
  return MockClient((_) async => http.Response(body, statusCode));
}

/// Builds a [MockClient] that returns different bodies keyed by URL path.
http.Client _mockHttpByUrl(Map<String, String> urlToBody) {
  return MockClient((request) async {
    final body = urlToBody[request.url.toString()];
    if (body == null) {
      return http.Response('not found', 404);
    }
    return http.Response(body, 200);
  });
}

FileDelta _addDelta(String path, {String url = 'https://example.com/file'}) =>
    FileDelta(relativePath: path, type: DeltaType.add, downloadUrl: url);

FileDelta _updateDelta(
  String path, {
  String url = 'https://example.com/file',
}) => FileDelta(relativePath: path, type: DeltaType.update, downloadUrl: url);

FileDelta _deleteDelta(String path) =>
    FileDelta(relativePath: path, type: DeltaType.delete);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_writer_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // ── add ────────────────────────────────────────────────────────────────────

  group('FileWriter — add', () {
    test('creates the file with downloaded content', () async {
      final writer = FileWriter(httpClient: _mockHttp(body: 'hello world'));
      await writer.apply(tempDir, [_addDelta('notes.txt')]);

      final file = File('${tempDir.path}/notes.txt');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), 'hello world');
    });

    test('creates intermediate directories', () async {
      final writer = FileWriter(httpClient: _mockHttp());
      await writer.apply(tempDir, [_addDelta('week1/assignments/hw1.pdf')]);

      final file = File('${tempDir.path}/week1/assignments/hw1.pdf');
      expect(await file.exists(), isTrue);
    });

    test('increments filesAdded count', () async {
      final writer = FileWriter(httpClient: _mockHttp());
      final result = await writer.apply(tempDir, [
        _addDelta('a.txt'),
        _addDelta('b.txt'),
      ]);

      expect(result.filesAdded, 2);
      expect(result.filesUpdated, 0);
      expect(result.filesDeleted, 0);
    });

    test('records error and continues when download fails', () async {
      final writer = FileWriter(httpClient: _mockHttp(statusCode: 404));
      final result = await writer.apply(tempDir, [
        _addDelta('bad.txt'),
        _addDelta('also-bad.txt'),
      ]);

      expect(result.errors, hasLength(2));
      expect(result.filesAdded, 0);
    });

    test(
      'partial failure: succeeds on good URLs, records errors on bad ones',
      () async {
        final writer = FileWriter(
          httpClient: _mockHttpByUrl({
            'https://example.com/good': 'good content',
            // 'https://example.com/bad' intentionally absent → 404
          }),
        );

        final result = await writer.apply(tempDir, [
          _addDelta('good.txt', url: 'https://example.com/good'),
          _addDelta('bad.txt', url: 'https://example.com/bad'),
        ]);

        expect(result.filesAdded, 1);
        expect(result.errors, hasLength(1));
        expect(result.errors.first, contains('bad.txt'));

        final good = File('${tempDir.path}/good.txt');
        expect(await good.exists(), isTrue);
      },
    );
  });

  // ── update ─────────────────────────────────────────────────────────────────

  group('FileWriter — update', () {
    test('overwrites an existing file with new content', () async {
      // Write an initial version
      final file = File('${tempDir.path}/notes.txt');
      await file.writeAsString('old content');

      final writer = FileWriter(httpClient: _mockHttp(body: 'new content'));
      await writer.apply(tempDir, [_updateDelta('notes.txt')]);

      expect(await file.readAsString(), 'new content');
    });

    test('increments filesUpdated count', () async {
      final writer = FileWriter(httpClient: _mockHttp());
      final result = await writer.apply(tempDir, [
        _updateDelta('x.txt'),
        _updateDelta('y.txt'),
      ]);

      expect(result.filesUpdated, 2);
      expect(result.filesAdded, 0);
    });
  });

  // ── delete ─────────────────────────────────────────────────────────────────

  group('FileWriter — delete', () {
    test('removes an existing file', () async {
      final file = File('${tempDir.path}/old.txt');
      await file.writeAsString('bye');

      final writer = FileWriter(httpClient: _mockHttp());
      await writer.apply(tempDir, [_deleteDelta('old.txt')]);

      expect(await file.exists(), isFalse);
    });

    test('is idempotent when file does not exist', () async {
      final writer = FileWriter(httpClient: _mockHttp());

      // Should not throw even though the file is absent
      final result = await writer.apply(tempDir, [_deleteDelta('ghost.txt')]);

      expect(result.filesDeleted, 1);
      expect(result.errors, isEmpty);
    });

    test('increments filesDeleted count', () async {
      final file = File('${tempDir.path}/a.txt');
      await file.writeAsString('x');

      final writer = FileWriter(httpClient: _mockHttp());
      final result = await writer.apply(tempDir, [_deleteDelta('a.txt')]);

      expect(result.filesDeleted, 1);
    });
  });

  // ── mixed batch ────────────────────────────────────────────────────────────

  group('FileWriter — mixed batch', () {
    test('handles adds, updates, and deletes in a single call', () async {
      // Pre-create the files that will be updated/deleted
      await File('${tempDir.path}/update-me.txt').writeAsString('old');
      await File('${tempDir.path}/delete-me.txt').writeAsString('bye');

      final writer = FileWriter(httpClient: _mockHttp(body: 'downloaded'));

      final result = await writer.apply(tempDir, [
        _addDelta('new.txt'),
        _updateDelta('update-me.txt'),
        _deleteDelta('delete-me.txt'),
      ]);

      expect(result.filesAdded, 1);
      expect(result.filesUpdated, 1);
      expect(result.filesDeleted, 1);
      expect(result.totalChanges, 3);
      expect(result.errors, isEmpty);
    });
  });

  // ── result helpers ─────────────────────────────────────────────────────────

  group('FileWriterResult', () {
    test('hasErrors is false when errors list is empty', () {
      const result = FileWriterResult(filesAdded: 1);
      expect(result.hasErrors, isFalse);
    });

    test('hasErrors is true when errors list is non-empty', () {
      const result = FileWriterResult(errors: ['oops.txt: download failed']);
      expect(result.hasErrors, isTrue);
    });

    test('totalChanges sums all three counters', () {
      const result = FileWriterResult(
        filesAdded: 2,
        filesUpdated: 3,
        filesDeleted: 1,
      );
      expect(result.totalChanges, 6);
    });
  });

  // ── security ───────────────────────────────────────────────────────────────

  // group('FileWriter — path traversal guard', () {
  //   test('rejects relativePath that escapes targetFolder', () async {
  //     final writer = FileWriter(httpClient: _mockHttp());
  //
  //     final result = await writer.apply(tempDir, [
  //       _addDelta('../../etc/passwd'),
  //     ]);
  //
  //     // Should record as an error, not write to disk
  //     expect(result.errors, hasLength(1));
  //     expect(result.filesAdded, 0);
  //   });
  // });
}
