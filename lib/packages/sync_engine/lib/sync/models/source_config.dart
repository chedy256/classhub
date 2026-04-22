// lib/sync/models/source_config.dart

/// Represents the type of source being synced.
enum SourceType { github, drive, classroom }

/// The current synchronization state of a source.
enum SyncStatus { idle, syncing, error, never }

class SourceConfig {
  final SourceType type;
  final String url;
  final int manifestVersion;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final String? checkpoint; // in github the checkpoint is the last commit

  /// The resolved branch name for this source.
  ///
  /// Populated on first sync from either the URL itself
  /// (e.g. github.com/owner/repo/tree/my-branch) or the GitHub API (default_branch).
  /// Stored to avoid re-fetching repo metadata for incremental diffs.
  final String? defaultBranch;

  /// Creates a new [SourceConfig].
  const SourceConfig({
    required this.type,
    required this.url,
    required this.syncStatus,
    required this.manifestVersion,
    this.lastSyncedAt,
    this.checkpoint,
    this.defaultBranch,
  });

  /// Creates a [SourceConfig] from a JSON map.
  factory SourceConfig.fromJson(Map<String, dynamic> json) {
    return SourceConfig(
      type: SourceType.values.byName(json['type'] as String),
      url: json['url'] as String,
      syncStatus: SyncStatus.values.byName(json['sync_status'] as String),
      manifestVersion: json['manifest_version'] as int,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      checkpoint: json['checkpoint'] as String?,
      defaultBranch: json['default_branch'] as String?,
    );
  }

  /// Converts this [SourceConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'url': url,
      'sync_status': syncStatus.name,
      'manifest_version': manifestVersion,
      'last_synced_at': lastSyncedAt?.toUtc().toIso8601String(),
      'checkpoint': checkpoint,
      'default_branch': defaultBranch,
    };
  }

  /// Creates a copy of this [SourceConfig] with the given fields replaced.
  SourceConfig copyWith({
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    String? checkpoint,
    String? defaultBranch,
  }) {
    return SourceConfig(
      type: type,
      url: url,
      manifestVersion: manifestVersion,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      checkpoint: checkpoint ?? this.checkpoint,
      defaultBranch: defaultBranch ?? this.defaultBranch,
    );
  }
}
