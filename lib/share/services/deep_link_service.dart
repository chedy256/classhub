import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';

class LinkService {
  final _appLinks = AppLinks();

  // ─── DEEP LINK BUILDER ───────────────────────────────────────────────────

  /// Construit le lien HTTPS deep link
  /// Format: https://classhub.knisium.com/add?url=URL1&url=URL2&url=URL3
  String buildAddSourcesDeepLinkString(List<String> urls) {
    final cleaned = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      throw ArgumentError('urls must not be empty');
    }

    // Support multiple URLs as repeated query parameters
    final urlParams = cleaned
        .map((u) => 'url=${Uri.encodeComponent(u)}')
        .join('&');
    return 'https://classhub.knisium.com/add?$urlParams';
  }

  // ─── SHARE & CLIPBOARD ───────────────────────────────────────────────────

  /// Partage le lien via le système natif
  Future<void> shareSheet(List<String> urls) async {
    final link = buildAddSourcesDeepLinkString(urls);
    await Share.share(link);
  }

  /// Copie le lien dans le presse-papiers
  Future<void> copyToClipboard(List<String> urls) async {
    final link = buildAddSourcesDeepLinkString(urls);
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

  /// Extrait les URLs depuis une chaîne d'entrée
  /// Supporte:
  /// - URL directes (https://github.com/owner/repo)
  /// - Liens Classhub (https://classhub.knisium.com/add?url=...)
  /// - classhub://add?url=...
  List<String> extractUrlsFromInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return [];

    List<String> results = [];

    // Essayer de parser comme URI
    try {
      final uri = Uri.parse(trimmed);

      // Si c'est un lien Classhub, extraire les URLs internes
      if (uri.host == 'classhub.knisium.com' && uri.path.startsWith('/add')) {
        return uri.queryParametersAll['url'] ?? [];
      }

      // Si c'est un scheme custom classhub
      if (uri.scheme == 'classhub' && uri.host == 'add') {
        return uri.queryParametersAll['url'] ?? [];
      }

      // Sinon, vérifier si c'est une URL directe valide
      if (uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http')) {
        if (uri.host.isNotEmpty) {
          results.add(trimmed);
        }
      }
    } catch (_) {}

    // Fallback: si ça ressemble à une URL GitHub directe
    if (results.isEmpty && _looksLikeGitHubUrl(trimmed)) {
      results.add(trimmed);
    }

    return results;
  }

  bool _looksLikeGitHubUrl(String url) {
    return url.contains('github.com/') && !url.contains(' ');
  }

  // ─── APP LINKS ───────────────────────────────────────────────────────────

  /// Retourne le lien initial (cold start)
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Stream des liens reçus en cours d'exécution
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}
