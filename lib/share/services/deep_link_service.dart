import 'package:app_links/app_links.dart';

class DeepLinkService {
  final _appLinks = AppLinks();

  // Returns the list of urls from /add?url=...&url=... links, empty list if invalid
  List<String> extractAddUrls(Uri uri) {
    final isHttpAdd =
        uri.host == 'classhub.knisium.com' && uri.path.startsWith('/add');
    final isCustomAdd = uri.scheme == 'classhub' && uri.host == 'add';

    if (isHttpAdd || isCustomAdd) {
      return uri.queryParametersAll['url'] ?? [];
    }
    return [];
  }

  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}
