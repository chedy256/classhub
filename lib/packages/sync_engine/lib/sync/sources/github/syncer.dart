// lib/sync/sources/github/syncer.dart

import 'package:sync_engine/sync/sources/github/parser.dart';

import '../../models/file_delta.dart';
import '../../models/source_config.dart';
import '../../models/syncer_output.dart';
import '../source_syncer.dart';
import 'http_client.dart';

class GithubSyncer implements SourceSyncer {
  final HttpClient _http;
  final GithubParser _parser;

  GithubSyncer([HttpClient? http, GithubParser? parser])
    : _http = http ?? HttpClient(),
      _parser = parser ?? GithubParser(http);

  // ── public ───────────────────────────────────────────────────────────────────

  @override
  Future<SyncerOutput> getDeltas(SourceConfig config) async {
    final (owner, repo, _) = _parser.parseUrl(config.url);
    final branch = config.defaultBranch;

    return config.checkpoint == null
        ? _fullClone(owner, repo, branch!)
        : _diff(owner, repo, config.checkpoint!, branch!);
  }

  // ── full clone ───────────────────────────────────────────────────────────────

  Future<SyncerOutput> _fullClone(
    String owner,
    String repo,
    String branch,
  ) async {
    // 1. branch metadata → commit SHA (to persist) + tree SHA (to list files)
    final branchMeta = await _http.getJson(
      'https://api.github.com/repos/$owner/$repo/branches/$branch',
    );
    final commitSha = branchMeta['commit']['sha'] as String;
    final treeSha = branchMeta['commit']['commit']['tree']['sha'] as String;

    // 2. recursive tree → every file in the repo in one call
    final treeData = await _http.getJson(
      'https://api.github.com/repos/$owner/$repo/git/trees/$treeSha?recursive=1',
    );

    // GitHub truncates trees above ~100k blobs or 7MB — unusable for full clone
    if (treeData['truncated'] == true) {
      throw StateError(
        'Repository $owner/$repo tree is truncated by the GitHub API — too large to sync.',
      );
    }

    // 3. filter to blobs only (entries can also be 'tree' = directory nodes)
    //    and build a download URL for each file
    final entries = treeData['tree'] as List<dynamic>;
    final deltas = entries.where((e) => e['type'] == 'blob').map((e) {
      final path = e['path'] as String;
      return FileDelta(
        relativePath: path,
        type: DeltaType.add,
        // raw.githubusercontent.com serves file content directly,
        // no API rate limit, no auth needed for public repos
        downloadUrl:
            'https://raw.githubusercontent.com/$owner/$repo/$branch/$path',
      );
    }).toList();

    return SyncerOutput(deltas: deltas, checkpoint: commitSha);
  }

  // ── incremental diff ─────────────────────────────────────────────────────────

  Future<SyncerOutput> _diff(
    String owner,
    String repo,
    String lastCommit,
    String branch,
  ) async {
    // Compare last known commit against current HEAD of the stored branch.
    // No repo metadata fetch needed — branch is already resolved by getDeltas.
    final compareData = await _http.getJson(
      'https://api.github.com/repos/$owner/$repo/compare/$lastCommit...$branch',
    );

    // Nothing changed since last sync — return early, no writes needed
    final commits = compareData['commits'] as List<dynamic>;
    if (commits.isEmpty) {
      return SyncerOutput(deltas: const [], checkpoint: lastCommit);
    }

    final newCommitSha = commits.last['sha'] as String;
    final files = compareData['files'] as List<dynamic>;

    // Map each changed file to one or two deltas
    final deltas = <FileDelta>[];
    for (final f in files) {
      final status = f['status'] as String;
      final path = f['filename'] as String;
      // raw_url from compare API is commit-pinned — correct for diff
      final rawUrl = f['raw_url'] as String?;

      switch (status) {
        case 'added':
          deltas.add(
            FileDelta(
              relativePath: path,
              type: DeltaType.add,
              downloadUrl: rawUrl,
            ),
          );
        case 'modified':
          deltas.add(
            FileDelta(
              relativePath: path,
              type: DeltaType.update,
              downloadUrl: rawUrl,
            ),
          );
        case 'removed':
          deltas.add(FileDelta(relativePath: path, type: DeltaType.delete));
        case 'renamed':
          // treat as: delete the old path, add the new path
          deltas.add(
            FileDelta(
              relativePath: f['previous_filename'] as String,
              type: DeltaType.delete,
            ),
          );
          deltas.add(
            FileDelta(
              relativePath: path,
              type: DeltaType.add,
              downloadUrl: rawUrl,
            ),
          );
        default:
          // 'copied', 'changed', 'unchanged' — no action needed for MVP
          break;
      }
    }

    return SyncerOutput(deltas: deltas, checkpoint: newCommitSha);
  }
}
