import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sync_engine/sync_engine.dart';
import 'package:test/test.dart';

class FailingHttpClient implements http.Client {
  final int failAfterCount;
  int _requestCount = 0;

  FailingHttpClient(this.failAfterCount);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    _requestCount++;
    if (_requestCount > failAfterCount) {
      throw SocketException('Simulated crash after $failAfterCount downloads');
    }
    return http.Response('content for $_requestCount', 200);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  void close() {}

  @override
  Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
}

class MockHttpClient implements http.Client {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response('content', 200);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  void close() {}

  @override
  Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();

  @override
  Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      throw UnimplementedError();
}

class FakeSyncer implements SourceSyncer {
  final List<FileDelta> deltas;
  final String? checkpoint;

  FakeSyncer(this.deltas, this.checkpoint);

  @override
  Future<SyncerOutput> getDeltas(SourceConfig config) async {
    return SyncerOutput(deltas: deltas, checkpoint: checkpoint);
  }
}

void main() {
  group('SyncEngine resume from queue', () {
    late Directory appFolder;

    setUp(() {
      appFolder = Directory.systemTemp.createTempSync('classhub_test_');
    });

    tearDown(() {
      if (appFolder.existsSync()) {
        appFolder.deleteSync(recursive: true);
      }
    });

    test('resumes from queue after interrupt, skipping completed files', () async {
      const url = 'https://github.com/owner/repo';

      final deltas = [
        FileDelta(relativePath: 'a.txt', type: DeltaType.add, downloadUrl: 'https://example.com/a.txt'),
        FileDelta(relativePath: 'b.txt', type: DeltaType.add, downloadUrl: 'https://example.com/b.txt'),
        FileDelta(relativePath: 'c.txt', type: DeltaType.add, downloadUrl: 'https://example.com/c.txt'),
        FileDelta(relativePath: 'd.txt', type: DeltaType.add, downloadUrl: 'https://example.com/d.txt'),
      ];

      final fakeSyncer = FakeSyncer(deltas, 'abc123');

      // First attempt: fail after 2 downloads (simulating interrupt)
      final failingClient = FailingHttpClient(2);
      final engine1 = SyncEngine(
        appFolder: appFolder,
        parsers: [_FakeParser(url)],
        syncers: {SourceType.github: fakeSyncer},
        fileWriter: FileWriter(httpClient: failingClient),
      );

      var result = await engine1.addSource(url);
      expect(result.success, isFalse);

      // Verify queue was persisted with partial progress
      final sourceFolder = Directory('${appFolder.path}/repo');
      expect(sourceFolder.existsSync(), isTrue);

      // Second attempt: should resume with only pending deltas (c.txt, d.txt)
      final completeClient = MockHttpClient();
      final engine2 = SyncEngine(
        appFolder: appFolder,
        parsers: [_FakeParser(url)],
        syncers: {SourceType.github: fakeSyncer},
        fileWriter: FileWriter(httpClient: completeClient),
      );

      result = await engine2.addSource(url);
      expect(result.success, isTrue);
      // Only 2 files should be downloaded on resume (c.txt, d.txt)
      expect(result.totalChanges, equals(2));

      // Verify all files exist in final folder
      final finalFolder = Directory('${appFolder.path}/repo');
      expect(File('${finalFolder.path}/a.txt').existsSync(), isTrue);
      expect(File('${finalFolder.path}/b.txt').existsSync(), isTrue);
      expect(File('${finalFolder.path}/c.txt').existsSync(), isTrue);
      expect(File('${finalFolder.path}/d.txt').existsSync(), isTrue);
    });

    test('syncer is NOT called on resume', () async {
      const url = 'https://github.com/owner/repo';

      final deltas = [
        FileDelta(relativePath: 'a.txt', type: DeltaType.add, downloadUrl: 'https://example.com/a.txt'),
        FileDelta(relativePath: 'b.txt', type: DeltaType.add, downloadUrl: 'https://example.com/b.txt'),
      ];

      var syncerCallCount = 0;
      final fakeSyncer = _CountingSyncer(deltas, 'abc123', () => syncerCallCount++);

      // First attempt: fail after 1 download
      final failingClient = FailingHttpClient(1);
      final engine1 = SyncEngine(
        appFolder: appFolder,
        parsers: [_FakeParser(url)],
        syncers: {SourceType.github: fakeSyncer},
        fileWriter: FileWriter(httpClient: failingClient),
      );

      await engine1.addSource(url);

      final syncerCallsBeforeResume = syncerCallCount;
      expect(syncerCallsBeforeResume, equals(1)); // called once on first attempt

      // Second attempt: should NOT call the syncer (uses existing queue)
      final completeClient = MockHttpClient();
      final engine2 = SyncEngine(
        appFolder: appFolder,
        parsers: [_FakeParser(url)],
        syncers: {SourceType.github: fakeSyncer},
        fileWriter: FileWriter(httpClient: completeClient),
      );

      await engine2.addSource(url);

      expect(syncerCallCount, equals(1)); // still only 1, not called again
    });
  });
}

class _FakeParser implements SourceParser {
  final String url;

  _FakeParser(this.url);

  @override
  bool canParse(String candidate) => candidate == url;

  @override
  Future<SourceConfig> parseUrlToSourceConfig(String candidate) async {
    return SourceConfig(
      type: SourceType.github,
      url: candidate,
      syncStatus: SyncStatus.never,
      manifestVersion: 1,
    );
  }

  @override
  String getSourceFolderName(String candidate) => 'repo';

  @override
  SourceType get sourceType => SourceType.github;
}

class _CountingSyncer implements SourceSyncer {
  final List<FileDelta> deltas;
  final String? checkpoint;
  final void Function() onCall;

  _CountingSyncer(this.deltas, this.checkpoint, this.onCall);

  @override
  Future<SyncerOutput> getDeltas(SourceConfig config) async {
    onCall();
    return SyncerOutput(deltas: deltas, checkpoint: checkpoint);
  }
}
