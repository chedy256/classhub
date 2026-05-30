import '../../models/file_delta.dart';
import '../../models/source_config.dart';
import '../../models/syncer_output.dart';
import '../source_syncer.dart';
import 'http_client.dart';

class DriveSyncer implements SourceSyncer {
  final DriveApiClient _http;

  DriveSyncer([DriveApiClient? http]) : _http = http ?? DriveApiClient();

  @override
  Future<SyncerOutput> getDeltas(SourceConfig config) async {
    print(
      '[DEBUG] DriveSyncer.getDeltas: config.type=${config.type} config.folderId="${config.folderId}" config.url="${config.url}" config.toJson()=${config.toJson()}',
    );
    final folderId = config.folderId;
    if (folderId == null || folderId.isEmpty) {
      throw ArgumentError('Drive source config must have a folderId');
    }
    final deltas = <FileDelta>[];
    await _listFolder(folderId, '', deltas);
    return SyncerOutput(
      deltas: deltas,
      checkpoint: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _listFolder(
    String folderId,
    String prefix,
    List<FileDelta> deltas,
  ) async {
    String? pageToken;
    do {
      final q = "'$folderId'+in+parents+and+trashed=false";
      final url = StringBuffer(
        'https://www.googleapis.com/drive/v3/files?q=$q'
        '&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)',
      );
      if (pageToken != null) url.write('&pageToken=$pageToken');

      final data = await _http.getJson(url.toString());
      final files = data['files'] as List<dynamic>? ?? [];

      for (final f in files) {
        final mimeType = f['mimeType'] as String? ?? '';
        final name = f['name'] as String? ?? '';
        final fileId = f['id'] as String? ?? '';
        final relativePath = prefix.isEmpty ? name : '$prefix/$name';
        if (mimeType == 'application/vnd.google-apps.folder') {
          await _listFolder(fileId, relativePath, deltas);
        } else {
          deltas.add(
            FileDelta(
              relativePath: relativePath,
              type: DeltaType.add,
              downloadUrl: _buildDownloadUrl(fileId, mimeType),
              size: f['size'] != null ? int.tryParse(f['size'].toString()) : null,
              downloadHeaders: await _http.authHeaders,
            ),
          );
        }
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
  }

  String _buildDownloadUrl(String fileId, String mimeType) {
    final key = _http.apiKey ?? '';
    if (key.isEmpty) return '';

    if (_isGoogleNativeFile(mimeType)) {
      return 'https://www.googleapis.com/drive/v3/files/$fileId/export?mimeType=application/pdf&key=$key';
    }
    return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media&key=$key';
  }

  static bool _isGoogleNativeFile(String mimeType) {
    return mimeType.startsWith('application/vnd.google-apps.') &&
        mimeType != 'application/vnd.google-apps.folder';
  }
}
