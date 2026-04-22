import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

// TODO: separate each syncer http client
// consider putting each syncer http client in the same folder in its own services
class HttpClient {
  final String? _token;

  /// [token] is optional. Without it, GitHub allows 60 requests/hour.
  /// With a personal access token, the limit rises to 5000/hour.
  HttpClient({String? token}) : _token = token;

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Fetches [url] and returns the decoded JSON body as a map.
  /// Throws [HttpException] on non-200 responses.
  Future<Map<String, dynamic>> getJson(String url) async {
    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 403 || response.statusCode == 429) {
      throw HttpException(
        'Rate limit exceeded: GET $url returned ${response.statusCode}',
      );
    } else if (response.statusCode != 200) {
      throw HttpException(
        'GET $url returned ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
