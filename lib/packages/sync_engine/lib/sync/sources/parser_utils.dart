import 'source_parser.dart';
import 'github/parser.dart';

final List<SourceParser> _allParsers = [GithubParser()];

String getSourceFolderName(String url) {
  for (final parser in _allParsers) {
    if (parser.canParse(url)) {
      return parser.getSourceFolderName(url);
    }
  }
  throw ArgumentError('Unsupported source URL: $url');
}
