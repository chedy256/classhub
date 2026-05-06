import 'dart:convert';
import 'package:http/http.dart' as http;
import 'classhub_storage_service.dart';
import '../version.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
  });
}

Future<UpdateInfo?> checkForUpdate() async {
  try {
    final token = await ClasshubStorageService.getGithubToken();
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(
          Uri.parse(
              'https://api.github.com/repos/titanknis/classhub/releases/latest'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? '';

    if (tagName.isEmpty || htmlUrl.isEmpty) return null;

    final latestVersion =
        tagName.startsWith('v') ? tagName.substring(1) : tagName;

    if (_isNewerVersion(latestVersion, appVersion)) {
      return UpdateInfo(
        latestVersion: latestVersion,
        releaseUrl: htmlUrl,
      );
    }

    return null;
  } catch (_) {
    return null;
  }
}

bool _isNewerVersion(String latest, String current) {
  final latestParts = latest.split('.').map(int.tryParse).toList();
  final currentParts = current.split('.').map(int.tryParse).toList();

  if (latestParts.length != 3 || currentParts.length != 3) {
    return latest != current;
  }

  for (int i = 0; i < 3; i++) {
    final l = latestParts[i] ?? 0;
    final c = currentParts[i] ?? 0;
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}
