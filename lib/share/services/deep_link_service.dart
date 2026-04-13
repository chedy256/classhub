import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';

class LinkService {
  final _appLinks = AppLinks();

  // ─── DEEP LINK BUILDER ───────────────────────────────────────────────────

  /// Construit le lien HTTPS deep link
  /// Format: https://classhub.knisium.com/add?url=URL_ENCODEE
  String buildAddSourcesDeepLinkString(List<String> urls) {
    final cleaned = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      throw ArgumentError('urls must not be empty');
    }

    final encodedUrl = Uri.encodeComponent(cleaned.first);
    return 'https://classhub.knisium.com/add?url=$encodedUrl';
  }

  // ─── SHARE & CLIPBOARD ───────────────────────────────────────────────────

  /// Partage le lien via le système natif
  Future<void> shareSheet(List<String> urls) async {
    final link = buildAddSourcesDeepLinkString(urls);
    print("LIEN PARTAGÉ: $link");
    await Share.share(link);
  }

  /// Copie le lien dans le presse-papiers
  Future<void> copyToClipboard(List<String> urls) async {
    final link = buildAddSourcesDeepLinkString(urls);
    print(" LIEN COPIÉ: $link");
    await Clipboard.setData(ClipboardData(text: link));
  }

  // ─── DEEP LINK PARSER ────────────────────────────────────────────────────

  /// Extrait les URLs depuis un lien /add?url=...
  /// Supporte le format HTTPS et le scheme custom (classhub://)
  List<String> extractAddUrls(Uri uri) {
    final isHttpAdd =
        uri.host == 'classhub.knisium.com' && uri.path.startsWith('/add');
    final isCustomAdd = uri.scheme == 'classhub' && uri.host == 'add';

    if (isHttpAdd || isCustomAdd) {
      return uri.queryParametersAll['url'] ?? [];
    }
    return [];
  }

  // ─── APP LINKS ───────────────────────────────────────────────────────────

  /// Retourne le lien initial (cold start)
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Stream des liens reçus en cours d'exécution
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}
