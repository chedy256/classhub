import 'package:test/test.dart';
import 'package:sync_engine/sync/sources/drive/drive_syncer.dart';
import 'package:sync_engine/sync/sources/drive/http_client.dart';
import 'package:sync_engine/sync/models/source_config.dart';
import 'package:sync_engine/sync/models/file_delta.dart';

class MockDriveApiClient extends DriveApiClient {
  final Map<String, dynamic> _responses = {};
  int getJsonCallCount = 0;
  String? lastCalledUrl;

  MockDriveApiClient({super.apiKey});

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
  late DriveSyncer syncer;
  late MockDriveApiClient mockHttp;

  setUp(() {
    mockHttp = MockDriveApiClient(apiKey: 'test-api-key');
    syncer = DriveSyncer(mockHttp);
  });

  group('DriveSyncer', () {
    group('getDeltas', () {
      test('throws ArgumentError when folderId is null', () async {
        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/abc123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
        );

        expect(() => syncer.getDeltas(config), throwsA(isA<ArgumentError>()));
      });

      test('throws ArgumentError when folderId is empty', () async {
        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: '',
        );

        expect(() => syncer.getDeltas(config), throwsA(isA<ArgumentError>()));
      });

      test('returns deltas for folder with files', () async {
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'file1',
                'name': 'notes.txt',
                'mimeType': 'text/plain',
                'size': 1024,
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
              {
                'id': 'file2',
                'name': 'syllabus.pdf',
                'mimeType': 'application/pdf',
                'size': 2048,
                'modifiedTime': '2024-01-02T00:00:00Z',
              },
            ],
          },
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.deltas.length, equals(2));
        expect(output.deltas[0].relativePath, equals('notes.txt'));
        expect(output.deltas[0].type, equals(DeltaType.add));
        expect(
          output.deltas[0].downloadUrl,
          contains('https://www.googleapis.com/drive/v3/files/file1?alt=media'),
        );
        expect(output.deltas[0].downloadUrl, contains('key=test-api-key'));
        expect(output.deltas[0].size, equals(1024));

        expect(output.deltas[1].relativePath, equals('syllabus.pdf'));
        expect(output.deltas[1].size, equals(2048));
        expect(output.checkpoint, isNotNull);
      });

      test('recurses into sub-folders', () async {
        // Root folder query
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'folder1',
                'name': 'Assignments',
                'mimeType': 'application/vnd.google-apps.folder',
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
              {
                'id': 'file_root',
                'name': 'readme.txt',
                'mimeType': 'text/plain',
                'size': 512,
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
            ],
          },
        );

        // Sub-folder query
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='folder1'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'file_a',
                'name': 'hw1.pdf',
                'mimeType': 'application/pdf',
                'size': 4096,
                'modifiedTime': '2024-01-03T00:00:00Z',
              },
              {
                'id': 'folder2',
                'name': 'SubDir',
                'mimeType': 'application/vnd.google-apps.folder',
                'modifiedTime': '2024-01-02T00:00:00Z',
              },
            ],
          },
        );

        // Nested sub-folder query
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='folder2'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'file_b',
                'name': 'deep.txt',
                'mimeType': 'text/plain',
                'size': 128,
                'modifiedTime': '2024-01-04T00:00:00Z',
              },
            ],
          },
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.deltas.length, equals(3));
        expect(output.deltas[0].relativePath, equals('Assignments/hw1.pdf'));
        expect(
          output.deltas[1].relativePath,
          equals('Assignments/SubDir/deep.txt'),
        );
        expect(output.deltas[2].relativePath, equals('readme.txt'));
      });

      test('handles pagination', () async {
        // First page
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'f1',
                'name': 'file1.txt',
                'mimeType': 'text/plain',
                'size': 100,
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
            ],
            'nextPageToken': 'page2token',
          },
        );

        // Second page
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)'
          '&pageToken=page2token',
          {
            'files': [
              {
                'id': 'f2',
                'name': 'file2.txt',
                'mimeType': 'text/plain',
                'size': 200,
                'modifiedTime': '2024-01-02T00:00:00Z',
              },
            ],
          },
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.deltas.length, equals(2));
        expect(output.deltas[0].relativePath, equals('file1.txt'));
        expect(output.deltas[1].relativePath, equals('file2.txt'));
        expect(mockHttp.getJsonCallCount, equals(2));
      });

      test('uses export URL for Google-native files (Docs/Sheets)', () async {
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {
            'files': [
              {
                'id': 'doc1',
                'name': 'report',
                'mimeType': 'application/vnd.google-apps.document',
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
              {
                'id': 'sheet1',
                'name': 'grades',
                'mimeType': 'application/vnd.google-apps.spreadsheet',
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
              {
                'id': 'pdf1',
                'name': 'notes.pdf',
                'mimeType': 'application/pdf',
                'size': 512,
                'modifiedTime': '2024-01-01T00:00:00Z',
              },
            ],
          },
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.deltas.length, equals(3));

        // Google Doc uses export URL with mimeType=application/pdf
        expect(
          output.deltas[0].downloadUrl,
          contains('/files/doc1/export?mimeType=application/pdf'),
        );

        // Google Sheet uses export URL
        expect(
          output.deltas[1].downloadUrl,
          contains('/files/sheet1/export?mimeType=application/pdf'),
        );

        // Regular PDF uses alt=media
        expect(output.deltas[2].downloadUrl, contains('/files/pdf1?alt=media'));

        // All URLs include API key
        for (final d in output.deltas) {
          expect(d.downloadUrl, contains('key=test-api-key'));
        }
      });

      test('sets checkpoint to current timestamp', () async {
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {'files': []},
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.checkpoint, isNotNull);
        // Should be an ISO 8601 timestamp
        expect(DateTime.tryParse(output.checkpoint!), isNotNull);
      });

      test('handles empty folder', () async {
        mockHttp.addResponse(
          'https://www.googleapis.com/drive/v3/files'
          "?q='root123'+in+parents+and+trashed=false"
          '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
          {'files': []},
        );

        final config = SourceConfig(
          type: SourceType.drive,
          url: 'https://drive.google.com/drive/folders/root123',
          syncStatus: SyncStatus.never,
          manifestVersion: 1,
          folderId: 'root123',
        );

        final output = await syncer.getDeltas(config);

        expect(output.deltas, isEmpty);
        expect(output.checkpoint, isNotNull);
      });
    });
  });
}
