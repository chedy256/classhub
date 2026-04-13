import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:classhub/share/services/deep_link_service.dart';

class AddScreen extends StatefulWidget {
  final List<String> incomingUrls;
  const AddScreen({super.key, required this.incomingUrls});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _linkService = LinkService();
  final _urlController = TextEditingController();
  List<String> _urls = [];

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les URLs reçues par deep link
    _urls = List.from(widget.incomingUrls);
    _processUrls();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ─── LOGIQUE ─────────────────────────────────────────────────────────────

  void _processUrls() {
    if (kDebugMode) debugPrint('URLs reçues: $_urls');
  }

  void _addUrlFromInput() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _urls.add(url);
      _urlController.clear();
    });

    if (kDebugMode) debugPrint('URL ajoutée: $url');
  }

  void _removeUrl(int index) {
    setState(() => _urls.removeAt(index));
  }

  Future<void> _shareUrls() async {
    final urlsToShare = _getUrlsToShare();
    if (urlsToShare == null) return;

    try {
      await _linkService.shareSheet(urlsToShare);
    } catch (e) {
      _showSnackbar(' Erreur: $e');
    }
  }

  Future<void> _copyUrls() async {
    final urlsToShare = _getUrlsToShare();
    if (urlsToShare == null) return;

    try {
      await _linkService.copyToClipboard(urlsToShare);
      _showSnackbar(' Lien copié dans le presse-papiers');
    } catch (e) {
      _showSnackbar(' Erreur: $e');
    }
  }

  /// Retourne les URLs à partager ou affiche une erreur si vide
  List<String>? _getUrlsToShare() {
    if (_urls.isEmpty) {
      _showSnackbar(' Aucune URL à partager');
      return null;
    }
    return _urls;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Classhub')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Input URL ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Entrer une URL',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _addUrlFromInput(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _addUrlFromInput,
                  tooltip: 'Ajouter',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Boutons Partager / Copier ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Partager'),
                    onPressed: _shareUrls,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier le lien'),
                    onPressed: _copyUrls,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ── Liste des URLs ─────────────────────────────────────────────
            if (_urls.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Aucune URL ajoutée',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _urls.length,
                  itemBuilder: (context, index) {
                    final url = _urls[index];
                    return ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(
                        url,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeUrl(index),
                        tooltip: 'Supprimer',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
