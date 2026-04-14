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
      // Sort newest first
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
        backgroundColor: const Color(0xFF151822),
        title: const Text(
          'Delete permanently?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete ${toDelete.length} item${toDelete.length > 1 ? 's' : ''}. This cannot be undone.',
          style: const TextStyle(color: Color(0xFF8C95A6)),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showItemActions(TrashItem item, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore, color: Color(0xFF80A3FF)),
              title: const Text(
                'Restore',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _trashService.restoreItem(widget.rootPath, item);
                _load();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Item restored')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete permanently',
                style: TextStyle(color: Colors.red),
              ),
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
    const bgColor = Color(0xFF090C14);
    const cardColor = Color(0xFF111827);
    const accentBlue = Color(0xFF80A3FF);
    const subtitleColor = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _selectedIndices.clear();
                  _isSelecting = false;
                }),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: accentBlue),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelecting
            ? Text(
                '${_selectedIndices.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Text(
                'Trash',
                style: TextStyle(
                  color: accentBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _items.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: accentBlue,
                  ),
                  tooltip: _selectedIndices.length == _items.length
                      ? 'Deselect all'
                      : 'Select all',
                  onPressed: _selectAll,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _isSelecting && _selectedIndices.isNotEmpty
          ? SafeArea(
              child: Container(
                color: const Color(0xFF0F1420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restoreSelected,
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text(
                          'Restore',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentBlue,
                          side: BorderSide(
                            color: accentBlue.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                    color: subtitleColor.withValues(alpha: 0.4),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Trash is empty',
                    style: TextStyle(color: subtitleColor, fontSize: 14),
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

                return GestureDetector(
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentBlue.withValues(alpha: 0.1)
                          : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? accentBlue.withValues(alpha: 0.5)
                            : const Color(0xFF1F2937),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon / Checkbox
                        if (_isSelecting)
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentBlue.withValues(alpha: 0.2)
                                  : accentBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? accentBlue : subtitleColor,
                              size: 22,
                            ),
                          )
                        else
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accentBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(info.icon, color: accentBlue, size: 22),
                          ),
                        const SizedBox(width: 14),
                        // Name + metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    info.icon,
                                    color: subtitleColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    info.label,
                                    style: const TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '\u2022',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sizeStr,
                                    style: const TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Days remaining badge
                        if (!_isSelecting)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.daysRemaining <= 7
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : accentBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.daysRemaining}d',
                              style: TextStyle(
                                color: item.daysRemaining <= 7
                                    ? Colors.red.shade300
                                    : subtitleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
