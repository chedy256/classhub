import 'package:test/test.dart';
import 'package:sync_engine/sync/sources/drive/drive_parser.dart';
import 'package:sync_engine/sync/models/source_config.dart';

void main() {
  late DriveParser parser;

  setUp(() {
    parser = DriveParser();
  });

  group('DriveParser', () {
    group('canParse', () {
      test('returns true for https://drive.google.com/drive/folders/{id}', () {
        expect(
          parser.canParse('https://drive.google.com/drive/folders/abc123'),
          isTrue,
        );
      });

      test('returns true for drive.google.com/drive/folders/{id}', () {
        expect(
          parser.canParse('drive.google.com/drive/folders/abc123'),
          isTrue,
        );
      });

      test('returns true with query params (usp=sharing)', () {
        expect(
          parser.canParse(
            'https://drive.google.com/drive/folders/abc123?usp=sharing',
          ),
          isTrue,
        );
      });

      test('returns true with query params (usp=drive_link)', () {
        expect(
          parser.canParse(
            'https://drive.google.com/drive/folders/abc123?usp=drive_link',
          ),
          isTrue,
        );
      });

      test('returns false for google.com URL', () {
        expect(parser.canParse('https://google.com'), isFalse);
      });

      test('returns false for github.com URL', () {
        expect(parser.canParse('https://github.com/owner/repo'), isFalse);
      });

      test('returns false for random string', () {
        expect(parser.canParse('not-a-drive-url'), isFalse);
      });
    });

    group('getSourceFolderName', () {
      test('extracts folder ID from https URL', () {
        expect(
          parser.getSourceFolderName(
            'https://drive.google.com/drive/folders/abc123',
          ),
          equals('abc123'),
        );
      });

      test('extracts folder ID from URL without https://', () {
        expect(
          parser.getSourceFolderName('drive.google.com/drive/folders/abc123'),
          equals('abc123'),
        );
      });

      test('extracts folder ID from URL with query params', () {
        expect(
          parser.getSourceFolderName(
            'https://drive.google.com/drive/folders/abc123?usp=drive_link',
          ),
          equals('abc123'),
        );
      });

      test('extracts folder ID with hyphens', () {
        expect(
          parser.getSourceFolderName(
            'https://drive.google.com/drive/folders/1ABC-def_456',
          ),
          equals('1ABC-def_456'),
        );
      });
    });

    group('parseUrl', () {
      test('extracts folder ID from https URL', () {
        expect(
          parser.parseUrl('https://drive.google.com/drive/folders/abc123'),
          equals('abc123'),
        );
      });

      test('extracts folder ID without https://', () {
        expect(
          parser.parseUrl('drive.google.com/drive/folders/abc123'),
          equals('abc123'),
        );
      });

      test('strips query parameters', () {
        expect(
          parser.parseUrl(
            'https://drive.google.com/drive/folders/abc123?usp=sharing',
          ),
          equals('abc123'),
        );
      });

      test('throws ArgumentError for URL with no segments', () {
        expect(
          () => parser.parseUrl('https://drive.google.com/drive/folders/'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('parseUrlToSourceConfig', () {
      test('creates SourceConfig with correct values', () async {
        final config = await parser.parseUrlToSourceConfig(
          'https://drive.google.com/drive/folders/folder123',
        );

        expect(config.type, equals(SourceType.drive));
        expect(
          config.url,
          equals('https://drive.google.com/drive/folders/folder123'),
        );
        expect(config.folderId, equals('folder123'));
        expect(config.syncStatus, equals(SyncStatus.never));
        expect(config.manifestVersion, equals(1));
      });

      test(
        'creates SourceConfig with query params stripped from URL',
        () async {
          final config = await parser.parseUrlToSourceConfig(
            'https://drive.google.com/drive/folders/folder123?usp=drive_link',
          );

          expect(config.folderId, equals('folder123'));
          expect(
            config.url,
            equals(
              'https://drive.google.com/drive/folders/folder123?usp=drive_link',
            ),
          );
        },
      );
    });
  });
}
