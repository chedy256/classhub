import 'package:test/test.dart';
import 'package:sync_engine/sync/sources/github/parser.dart';
import 'package:sync_engine/sync/sources/github/http_client.dart';
import 'package:sync_engine/sync/models/source_config.dart';

void main() {
  late GithubParser parser;
  late MockHttpClient mockHttp;

  setUp(() {
    mockHttp = MockHttpClient();
    parser = GithubParser(mockHttp);
  });

  group('GithubParser', () {
    group('canParse', () {
      test('returns true for https://github.com/owner/repo', () {
        expect(parser.canParse('https://github.com/owner/repo'), isTrue);
      });

      test('returns true for github.com/owner/repo', () {
        expect(parser.canParse('github.com/owner/repo'), isTrue);
      });

      test('returns true for git@github.com:owner/repo.git', () {
        expect(parser.canParse('git@github.com:owner/repo.git'), isTrue);
      });

      test('returns true for git@github.com:owner/repo', () {
        expect(parser.canParse('git@github.com:owner/repo'), isTrue);
      });

      test('returns true for https://github.com/owner/repo/tree/main', () {
        expect(
          parser.canParse('https://github.com/owner/repo/tree/main'),
          isTrue,
        );
      });

      test('returns false for https://github.com/owner', () {
        expect(parser.canParse('https://github.com/owner'), isFalse);
      });

      test('returns false for https://example.com/owner/repo', () {
        expect(parser.canParse('https://example.com/owner/repo'), isFalse);
      });

      test('returns false for invalid URL', () {
        expect(parser.canParse('not-a-url'), isFalse);
      });

      // New test for URL with path after branch
      test('returns true for https://github.com/owner/repo/tree/main/path', () {
        expect(
          parser.canParse(
            'https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2',
          ),
          isTrue,
        );
      });
    });

    group('getSourceFolderName', () {
      test('extracts repo name from https URL', () {
        expect(
          parser.getSourceFolderName('https://github.com/owner/repo'),
          equals('repo'),
        );
      });

      test('extracts repo name from git URL with .git', () {
        expect(
          parser.getSourceFolderName('git@github.com:owner/repo.git'),
          equals('repo'),
        );
      });

      test('extracts repo name from git URL without .git', () {
        expect(
          parser.getSourceFolderName('git@github.com:owner/repo'),
          equals('repo'),
        );
      });

      test('extracts repo name from URL with branch', () {
        expect(
          parser.getSourceFolderName('https://github.com/owner/repo/tree/main'),
          equals('repo'),
        );
      });

      test('parses branch with slashes in path (not branch)', () {
        // This is the key test for your issue
        final (owner, repo, branch) = parser.parseUrl(
          'https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2',
        );
        expect(owner, equals('titanknis'));
        expect(repo, equals('ISIMM-L2-Info-Cours'));
        expect(
          branch,
          equals('main'),
        ); // Only 'main' is the branch, not 'main/Semestre2'
      });

      test('parses branch with actual slashes', () {
        final (owner, repo, branch) = parser.parseUrl(
          'https://github.com/owner/repo/tree/feature/new-feature',
        );
        expect(owner, equals('owner'));
        expect(repo, equals('repo'));
        expect(branch, equals('feature')); // Only 'feature' is the branch
      });
    });

    group('parseUrlToSourceConfig', () {
      test('creates SourceConfig with correct values for https URL', () async {
        final config = await parser.parseUrlToSourceConfig(
          'https://github.com/owner/repo',
        );

        expect(config.type, equals(SourceType.github));
        expect(config.url, equals('https://github.com/owner/repo'));
        expect(config.syncStatus, equals(SyncStatus.never));
        expect(config.manifestVersion, equals(1));
        expect(config.defaultBranch, equals('main')); // From mock
      });

      test('creates SourceConfig with correct values for git URL', () async {
        final config = await parser.parseUrlToSourceConfig(
          'git@github.com:owner/repo.git',
        );

        expect(config.type, equals(SourceType.github));
        expect(config.url, equals('git@github.com:owner/repo.git'));
        expect(config.defaultBranch, equals('main')); // From mock
      });

      test('creates SourceConfig with branch from URL', () async {
        // Mock to return branch from URL
        mockHttp.branchResponse = 'dev';
        final config = await parser.parseUrlToSourceConfig(
          'https://github.com/owner/repo/tree/dev',
        );

        expect(config.defaultBranch, equals('dev'));
      });

      test('throws ArgumentError for invalid URL', () async {
        expect(
          () => parser.parseUrlToSourceConfig('https://github.com/owner'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}

// Mock HttpClient for testing
class MockHttpClient extends HttpClient {
  String branchResponse = 'main';

  @override
  Future<Map<String, dynamic>> getJson(String url) async {
    if (url.contains('/repos/')) {
      return {'default_branch': branchResponse};
    }
    throw Exception('Unexpected URL: $url');
  }
}
