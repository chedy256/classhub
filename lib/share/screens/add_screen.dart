import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:io';
import 'package:classhub/share/services/deep_link_service.dart';
import 'package:sync_engine/sync_engine.dart';

class AddSourceDialog extends StatefulWidget {
  final List<String> incomingUrls;
  final String? rootPath;
  final VoidCallback? onAdded;
  const AddSourceDialog({
    super.key,
    this.incomingUrls = const [],
    this.rootPath,
    this.onAdded,
  });

  @override
  State<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<AddSourceDialog> {
  final _linkService = LinkService();
  final _urlController = TextEditingController();
  List<String> _urls = [];
  Set<int> _selected = {};
  bool _isLoading = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.incomingUrls);
    _selected = Set.from(List.generate(_urls.length, (i) => i));
    // If direct URLs (not Classhub), add them directly
    if (_urls.isNotEmpty &&
        !_isClasshubUrl(_urls.first) &&
        widget.rootPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addSelected();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _isClasshubUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == 'classhub.knisium.com' && uri.path.startsWith('/add');
    } catch (_) {
      return false;
    }
  }

  void _addUrlFromInput() {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    final isClasshub = _isClasshubUrl(input);

    if (isClasshub) {
      final extracted = _linkService.extractUrlsFromInput(input);
      if (extracted.isEmpty) {
        _showSnack('URL invalide');
        return;
      }
      setState(() {
        _urls = extracted;
        _selected = Set.from(List.generate(_urls.length, (i) => i));
      });
      _urlController.clear();
    } else {
      _addUrlDirectly(input);
    }
  }

  Future<void> _addUrlDirectly(String url) async {
    if (widget.rootPath == null) {
      _showSnack('Chemin racine non disponible');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Ajout en cours...';
    });

    try {
      final syncEngine = SyncEngine(appFolder: Directory(widget.rootPath!));
      final result = await syncEngine.addSource(url);

      if (result.success) {
        _showSnack('Source ajoutee');
        widget.onAdded?.call();
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack('Erreur: ${result.error}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnack('Erreur: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) {
      _showSnack('Selectionnez au moins une URL');
      return;
    }
    if (widget.rootPath == null) {
      _showSnack('Chemin racine non disponible');
      return;
    }

    final urlsToAdd = _selected.map((i) => _urls[i]).toList();
    final syncEngine = SyncEngine(appFolder: Directory(widget.rootPath!));

    setState(() => _isLoading = true);

    int success = 0;
    final errors = <String>[];

    for (var i = 0; i < urlsToAdd.length; i++) {
      setState(() {
        _loadingMessage = 'Ajout de ${i + 1}/${urlsToAdd.length}...';
      });

      try {
        final result = await syncEngine.addSource(urlsToAdd[i]);
        if (result.success) {
          success++;
        } else {
          errors.add('${_getRepoName(urlsToAdd[i])}: ${result.error}');
        }
      } catch (e) {
        errors.add('${_getRepoName(urlsToAdd[i])}: $e');
      }
    }

    setState(() => _isLoading = false);

    if (success == urlsToAdd.length) {
      _showSnack('$success source(s) ajoutee(s)');
      widget.onAdded?.call();
      if (mounted) Navigator.pop(context);
    } else if (success > 0) {
      _showSnack('$success ajoutee, ${errors.length} echouee(s)');
      widget.onAdded?.call();
      if (mounted) Navigator.pop(context);
    } else {
      _showSnack('Erreur: ${errors.first}');
    }
  }

  String _getRepoName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return segments[1];
      }
    } catch (_) {}
    return url;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Source'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://github.com/...',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _addUrlFromInput(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _isLoading ? null : _addUrlFromInput,
                ),
              ],
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(_loadingMessage ?? 'Ajout...'),
                ],
              ),
            ],
            if (_urls.isNotEmpty && !_isLoading) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _urls.length,
                  itemBuilder: (context, index) {
                    final url = _urls[index];
                    return CheckboxListTile(
                      value: _selected.contains(index),
                      onChanged: (_) => _toggleSelect(index),
                      title: Text(
                        _getRepoName(url),
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _selected.isEmpty ? null : _addSelected,
                child: Text(
                  _selected.isEmpty
                      ? 'Selectionner'
                      : 'Ajouter (${_selected.length})',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isLoading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
      ],
    );
  }
}
