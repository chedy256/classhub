import 'source_parser.dart';
import 'github/parser.dart';
import 'drive/drive_parser.dart';

final List<SourceParser> _allParsers = [GithubParser(), DriveParser()];

String getSourceFolderName(String url) {
  for (final parser in _allParsers) {
    if (parser.canParse(url)) {
      return parser.getSourceFolderName(url);
    }
  }
  throw ArgumentError('Unsupported source URL: $url');
}
