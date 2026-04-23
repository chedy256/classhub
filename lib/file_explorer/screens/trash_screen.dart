import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/file_type_info.dart';
import '../models/trash_item.dart';
import '../services/file_explorer_service.dart';
import '../services/trash_service.dart';

class TrashScreen extends StatefulWidget {
  final String rootPath;

  const TrashScreen({super.key, required this.rootPath});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService();
  final FileExplorerService _fileExplorerService = FileExplorerService();
  List<TrashItem> _items = [];
  final Set<int> _selectedIndices = {};
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _trashService.purgeExpired(widget.rootPath);
    setState(() {
      _items = _trashService.loadManifest(widget.rootPath);
      _items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      _selectedIndices.clear();
      if (_items.isEmpty) _isSelecting = false;
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelecting = false;
      } else {
        _selectedIndices.add(index);
        _isSelecting = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _items.length) {
        _selectedIndices.clear();
        _isSelecting = false;
      } else {
        _selectedIndices.addAll(List.generate(_items.length, (i) => i));
      }
    });
  }

  void _restoreSelected() {
    final toRestore = _selectedIndices.map((i) => _items[i]).toList();
    _trashService.restoreItems(widget.rootPath, toRestore);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Restored ${toRestore.length} item${toRestore.length > 1 ? 's' : ''}',
        ),
      ),
    );
  }

  void _deleteSelected() {
    final toDelete = _selectedIndices.map((i) => _items[i]).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'This will permanently delete ${toDelete.length} item${toDelete.length > 1 ? 's' : ''}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _trashService.permanentlyDeleteItems(widget.rootPath, toDelete);
              _load();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showItemActions(TrashItem item, int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore'),
              onTap: () {
                Navigator.pop(ctx);
                _trashService.restoreItem(widget.rootPath, item);
                _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item restored')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete permanently'),
              onTap: () {
                Navigator.pop(ctx);
                _trashService.permanentlyDelete(widget.rootPath, item);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  FileTypeInfo _classifyItem(TrashItem item) {
    return FileTypeInfo.classify(
      p.basename(item.originalPath),
      isDirectory: item.isDirectory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _isSelecting
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectedIndices.clear();
                  _isSelecting = false;
                }),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelecting
            ? Text('${_selectedIndices.length} selected')
            : const Text('Trash'),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _items.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: _selectAll,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _isSelecting && _selectedIndices.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restoreSelected,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restore'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: colorScheme.onSurfaceVariant,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trash is empty',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final name = p.basename(item.originalPath);
                final info = _classifyItem(item);
                final size = _trashService.entitySize(item);
                final sizeStr = _fileExplorerService.formatSize(size);
                final isSelected = _selectedIndices.contains(index);

                return Card(
                  color: isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (_isSelecting) {
                        _toggleSelect(index);
                      } else {
                        _showItemActions(item, index);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelecting) {
                        setState(() => _isSelecting = true);
                      }
                      _toggleSelect(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (_isSelecting)
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(info.icon),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      info.icon,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      info.label,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '·',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sizeStr,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!_isSelecting)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.daysRemaining <= 7
                                    ? colorScheme.errorContainer
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.daysRemaining}d',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: item.daysRemaining <= 7
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}