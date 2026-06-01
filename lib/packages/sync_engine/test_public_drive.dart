import 'package:http/http.dart' as http;

void main() async {
  final folderId = '13AFEAp1zuAz2v7c8o8-oLykW1YdDb6B4';
  final q = "'$folderId'+in+parents+and+trashed=false";
  final url =
      'https://www.googleapis.com/drive/v3/files?q=$q&fields=nextPageToken,files(id,name,mimeType,size,modifiedTime)';

  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
