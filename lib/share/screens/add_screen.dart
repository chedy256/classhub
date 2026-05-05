import 'package:flutter/material.dart';
import 'package:classhub/share/services/deep_link_service.dart';

class AddSourceDialog extends StatefulWidget {
  final List<String> incomingUrls;
  const AddSourceDialog({super.key, this.incomingUrls = const []});

  @override
  State<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<AddSourceDialog> {
  final _linkService = LinkService();
  final _urlController = TextEditingController();
  List<String> _urls = [];
  Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.incomingUrls);
    _selected = Set.from(List.generate(_urls.length, (i) => i));
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

  void _handleUrlInput() {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    if (_isClasshubUrl(input)) {
      final extracted = _linkService.extractUrlsFromInput(input);
      if (extracted.isEmpty) {
        _showSnack('URL invalide');
        return;
      }
      setState(() {
        _urls = extracted;
        _selected = Set.from(List.generate(_urls.length, (i) => i));
      });
    } else {
      _addUrlDirectly(input);
    }
  }

  void _addUrlDirectly(String url) {
    Navigator.pop(context, [url]);
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

  void _confirmSelected() {
    if (_selected.isEmpty) {
      _showSnack('Select at least one source');
      return;
    }
    Navigator.pop(
      context,
      _selected.map((i) => _urls[i]).toList(),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = _urls.isNotEmpty;
    return AlertDialog(
      title: Text(isSelecting ? 'Select Sources' : 'Add Source'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSelecting)
              TextField(
                controller: _urlController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://github.com/...',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _handleUrlInput(),
              )
            else ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
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
              Text(
                '${_selected.length} source(s) selected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isSelecting ? _confirmSelected : _handleUrlInput,
          child: Text(isSelecting ? 'Confirm' : 'Add'),
        ),
      ],
    );
  }
}
