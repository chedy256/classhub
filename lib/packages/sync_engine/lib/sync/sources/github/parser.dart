import '../../models/source_config.dart';
import '../source_parser.dart';
import 'http_client.dart';

class GithubParser implements SourceParser {
  final HttpClient _http;

  GithubParser([HttpClient? http]) : _http = http ?? HttpClient();

  @override
  SourceType get sourceType => SourceType.github;

  @override
  bool canParse(String url) {
    final isGitHubUrl =
        url.startsWith('https://github.com/') ||
        url.startsWith('github.com/') ||
        url.startsWith('git@github.com:');

    if (!isGitHubUrl) return false;

    try {
      final (owner, repo, _) = parseUrl(url);
      return owner.isNotEmpty && repo.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SourceConfig> parseUrlToSourceConfig(String url) async {
    final (owner, repo, branch) = parseUrl(url);
    final resolvedBranch = branch ?? await _fetchDefaultBranch(owner, repo);

    return SourceConfig(
      type: SourceType.github,
      url: url,
      syncStatus: SyncStatus.never,
      manifestVersion: 1,
      defaultBranch: resolvedBranch,
    );
  }

  // Helper to parse owner, repo, and branch from URL
  (String, String, String?) parseUrl(String url) {
    String path;
    if (url.startsWith('git@github.com:')) {
      // Handle git@github.com:owner/repo.git
      path = url.split('git@github.com:').last.split('.git').first;
    } else {
      // Handle https://github.com/owner/repo or github.com/owner/repo
      final uri = Uri.parse(url);
      path = uri.path;
    }

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.length < 2) {
      throw ArgumentError(
        'Invalid GitHub URL — expected owner/repo, got: $url',
      );
    }

    final owner = segments[0];
    final repo = segments[1].replaceAll('.git', ''); // Remove .git suffix

    String? branch;
    if (segments.length >= 3 && segments[2] == 'tree') {
      // Branch is the segment immediately after 'tree'
      if (segments.length > 3) {
        branch = segments[3];
        // If there are more segments, they are part of the path, not the branch
      }
    }

    return (owner, repo, branch);
  }

  Future<String> _fetchDefaultBranch(String owner, String repo) async {
    final repoMeta = await _http.getJson(
      'https://api.github.com/repos/$owner/$repo',
    );
    return repoMeta['default_branch'] as String;
  }

  @override
  String getSourceFolderName(String url) {
    final (_, repo, _) = parseUrl(url);
    return repo; // Repo name is already cleaned of .git suffix
  }
}

void main() {
  final parser = GithubParser();
  print(
    parser.parseUrl(
      "https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2",
    ),
  );
}
