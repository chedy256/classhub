import '../../models/source_config.dart';
import '../source_parser.dart';
import 'http_client.dart';

class DriveParser implements SourceParser {
  DriveParser([DriveApiClient? http]);

  @override
  SourceType get sourceType => SourceType.drive;

  @override
  bool canParse(String url) {
    final isDriveUrl =
        url.startsWith('https://drive.google.com/drive/folders/') ||
        url.startsWith('drive.google.com/drive/folders/');

    if (!isDriveUrl) return false;
    return true;
  }

  @override
  Future<SourceConfig> parseUrlToSourceConfig(String url) async {
    final folderId = parseUrl(url);
    print(
      '[DEBUG] DriveParser.parseUrlToSourceConfig: url="$url" folderId="$folderId"',
    );
    return SourceConfig(
      type: SourceType.drive,
      url: url,
      folderId: folderId,
      syncStatus: SyncStatus.never,
      manifestVersion: 1,
    );
  }

  String parseUrl(String url) {
    print('[DEBUG] DriveParser.parseUrl: raw url="$url"');
    if (url.startsWith('drive.google.com/drive/folders/')) {
      url = "https://$url";
    }

    // Uri.parse automatically separates the path from query parameters (like ?usp=drive_link)
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    print('[DEBUG] DriveParser.parseUrl: segments=$segments');

    if (segments.length < 3) {
      throw ArgumentError('Invalid Drive URL — expected folder ID, got: $url');
    }

    final result = segments.last;
    print('[DEBUG] DriveParser.parseUrl: result="$result"');
    return result;
  }

  @override
  String getSourceFolderName(String url) {
    return parseUrl(url);
  }
}

void main() {
  final parser = DriveParser();
  print(parser.parseUrl("GDrive parsing intialized"));
}
