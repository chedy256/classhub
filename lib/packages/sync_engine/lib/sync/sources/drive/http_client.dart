import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class DriveApiClient {
  final String? apiKey;
  Map<String, String>? _cachedHeaders;

  DriveApiClient({this.apiKey});

  Future<Map<String, String>> get authHeaders async {
    if (_cachedHeaders != null) return _cachedHeaders!;

    bool isAndroid = false;
    bool isIOS = false;
    try {
      isAndroid = Platform.isAndroid;
      isIOS = Platform.isIOS;
    } catch (_) {
      // Platform properties throw on web
    }

    if (!isAndroid && !isIOS) {
      _cachedHeaders = {};
      return _cachedHeaders!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (isAndroid) {
        _cachedHeaders = {
          'X-Android-Package': packageInfo.packageName,
          // Google Drive API expects a SHA-1 fingerprint for API key restrictions,
          // but package_info_plus `buildSignature` returns a SHA-256 fingerprint.
          // Because of this, it's safer to use the exact SHA-1 fingerprint you
          // registered in the Google Cloud Console, or pass it via dart-define.
          'X-Android-Cert': 'CCA143F4869A8CB09D0F2F81B3EB5A2E944970E8',
        };
      } else if (isIOS) {
        _cachedHeaders = {
          'X-Ios-Bundle-Identifier': packageInfo.packageName, // Bundle ID on iOS
        };
      }
    } catch (e) {
      _cachedHeaders = {};
    }

    return _cachedHeaders ?? {};
  }

  String _withKey(String url) {
    if (apiKey == null) return url;
    return url.contains('?') ? '$url&key=$apiKey' : '$url?key=$apiKey';
  }

  Future<Map<String, dynamic>> getJson(String url) async {
    final urlWithKey = _withKey(url);
    final response = await http.get(
      Uri.parse(urlWithKey),
      headers: await authHeaders,
    );

    if (response.statusCode == 403 || response.statusCode == 429) {
      throw HttpException(
        'Rate limit exceeded or Forbidden: GET $urlWithKey returned ${response.statusCode}\nBody: ${response.body}',
      );
    } else if (response.statusCode != 200) {
      throw HttpException(
        'GET $urlWithKey returned ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
