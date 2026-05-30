// test/sync/sources/github/syncer_test.dart
import 'package:test/test.dart';
import 'package:sync_engine/sync/sources/github/syncer.dart';
import 'package:sync_engine/sync/sources/github/parser.dart';
import 'package:sync_engine/sync/sources/github/http_client.dart';
import 'package:sync_engine/sync/models/source_config.dart';
import 'package:sync_engine/sync/models/file_delta.dart';

// Mock HttpClient for testing
class MockHttpClient implements HttpClient {
  final Map<String, dynamic> _responses = {};
  int getJsonCallCount = 0;
  String? lastCalledUrl;

  void addResponse(String url, dynamic response) {
    _responses[url] = response;
  }

  @override
  Future<Map<String, dynamic>> getJson(String url) async {
    getJsonCallCount++;
    lastCalledUrl = url;
    if (!_responses.containsKey(url)) {
      throw Exception('No mock response for URL: $url');
    }
    return _responses[url]! as Map<String, dynamic>;
  }
}

void main() {
  late GithubSyncer syncer;
  late MockHttpClient mockHttp;
  late GithubParser parser;

  setUp(() {
    mockHttp = MockHttpClient();
    parser = GithubParser(mockHttp);
    syncer = GithubSyncer(mockHttp, parser);
  });

  group('GithubSyncer', () {
    group('getDeltas', () {
      group('Full Clone', () {
        test('performs full clone when checkpoint is null', () async {
          // Setup mock responses for full clone
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/branches/main',
            {
              'commit': {
                'sha': 'abc123',
                'commit': {
                  'tree': {'sha': 'tree123'},
                },
              },
            },
          );
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/git/trees/tree123?recursive=1',
            {
              'tree': [
                {'path': 'file1.txt', 'type': 'blob'},
                {'path': 'dir/file2.txt', 'type': 'blob'},
                {'path': 'dir/', 'type': 'tree'}, // Should be filtered out
              ],
              'truncated': false,
            },
          );

          final config = SourceConfig(
            type: SourceType.github,
            url: 'https://github.com/owner/repo',
            syncStatus: SyncStatus.never,
            manifestVersion: 1,
            defaultBranch: 'main',
          );

          final output = await syncer.getDeltas(config);

          expect(output.deltas.length, equals(2));
          expect(output.deltas[0].relativePath, equals('file1.txt'));
          expect(output.deltas[0].type, equals(DeltaType.add));
          expect(output.deltas[1].relativePath, equals('dir/file2.txt'));
          expect(output.checkpoint, equals('abc123'));
        });

        test('throws error for truncated tree', () async {
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/branches/main',
            {
              'commit': {
                'sha': 'abc123',
                'commit': {
                  'tree': {'sha': 'tree123'},
                },
              },
            },
          );
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/git/trees/tree123?recursive=1',
            {'tree': [], 'truncated': true},
          );

          final config = SourceConfig(
            type: SourceType.github,
            url: 'https://github.com/owner/repo',
            syncStatus: SyncStatus.never,
            manifestVersion: 1,
            defaultBranch: 'main',
          );

          expect(
            () => syncer.getDeltas(config),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('truncated'),
              ),
            ),
          );
        });
      });

      group('Incremental Diff', () {
        test('performs diff when checkpoint exists', () async {
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/compare/old123...main',
            {
              'commits': [
                {'sha': 'new456'},
              ],
              'files': [
                {
                  'status': 'modified',
                  'filename': 'file1.txt',
                  'raw_url':
                      'https://raw.githubusercontent.com/owner/repo/main/file1.txt',
                },
                {'status': 'removed', 'filename': 'file2.txt'},
                {
                  'status': 'added',
                  'filename': 'file3.txt',
                  'raw_url':
                      'https://raw.githubusercontent.com/owner/repo/main/file3.txt',
                },
              ],
            },
          );

          final config = SourceConfig(
            type: SourceType.github,
            url: 'https://github.com/owner/repo',
            syncStatus: SyncStatus.idle,
            manifestVersion: 1,
            defaultBranch: 'main',
            checkpoint: 'old123',
          );

          final output = await syncer.getDeltas(config);

          expect(output.deltas.length, equals(3));
          expect(output.deltas[0].type, equals(DeltaType.update));
          expect(output.deltas[1].type, equals(DeltaType.delete));
          expect(output.deltas[2].type, equals(DeltaType.add));
          expect(output.checkpoint, equals('new456'));
        });

        test('handles renamed files as delete + add', () async {
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/compare/old123...main',
            {
              'commits': [
                {'sha': 'new456'},
              ],
              'files': [
                {
                  'status': 'renamed',
                  'filename': 'new_name.txt',
                  'previous_filename': 'old_name.txt',
                  'raw_url':
                      'https://raw.githubusercontent.com/owner/repo/main/new_name.txt',
                },
              ],
            },
          );

          final config = SourceConfig(
            type: SourceType.github,
            url: 'https://github.com/owner/repo',
            syncStatus: SyncStatus.idle,
            manifestVersion: 1,
            defaultBranch: 'main',
            checkpoint: 'old123',
          );

          final output = await syncer.getDeltas(config);

          expect(output.deltas.length, equals(2));
          expect(output.deltas[0].type, equals(DeltaType.delete));
          expect(output.deltas[0].relativePath, equals('old_name.txt'));
          expect(output.deltas[1].type, equals(DeltaType.add));
          expect(output.deltas[1].relativePath, equals('new_name.txt'));
        });

        test('returns empty deltas when no changes', () async {
          mockHttp.addResponse(
            'https://api.github.com/repos/owner/repo/compare/old123...main',
            {'commits': [], 'files': []},
          );

          final config = SourceConfig(
            type: SourceType.github,
            url: 'https://github.com/owner/repo',
            syncStatus: SyncStatus.idle,
            manifestVersion: 1,
            defaultBranch: 'main',
            checkpoint: 'old123',
          );

          final output = await syncer.getDeltas(config);

          expect(output.deltas, isEmpty);
          expect(output.checkpoint, equals('old123'));
        });
      });
    });
  });
}
