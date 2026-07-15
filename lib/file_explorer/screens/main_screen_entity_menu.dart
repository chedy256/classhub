part of 'main_screen.dart';

Future<String?> _showTextInputDialog(
  BuildContext context,
  String title,
  String hint,
  String action, {
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}

void _showEntityMenu(
  BuildContext context,
  FileSystemEntity entity,
  FileExplorerService service,
  VoidCallback onRefresh, {
  required String rootPath,
  required TrashService trashService,
  Future<void> Function()? onSync,
  SyncTracker? syncTracker,
}) {
  final insideSource = service.isInsideSource(entity.path, rootPath);
  final isSource = entity is Directory && service.isSyncedSource(entity.path);
  final linkService = LinkService();
  final sourceUrl = isSource ? service.getSourceUrl(entity.path) : null;

  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!insideSource || isSource)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(ctx);
                final oldName = p.basename(entity.path);
                final newName = await _showTextInputDialog(
                  context,
                  'Rename',
                  oldName,
                  'Rename',
                  initialValue: oldName,
                );
                if (newName != null &&
                    newName.isNotEmpty &&
                    newName != oldName) {
                  service.renameEntity(entity, newName);
                  onRefresh();
                }
              },
            ),
          if (!insideSource || isSource)
            ListTile(
              leading: const Icon(Icons.delete_outlined),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                final name = p.basename(entity.path);
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Move to Trash'),
                    content: Text('$name will be deleted after 30 days.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          trashService.moveToTrash(rootPath, entity);
                          onRefresh();
                        },
                        child: const Text('Move to trash'),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (onSync != null)
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync'),
              onTap: () {
                Navigator.pop(ctx);
                onSync();
              },
            ),
          if (sourceUrl != null)
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share source'),
              onTap: () {
                Navigator.pop(ctx);
                linkService.shareSheet([sourceUrl]);
              },
            ),
          if (entity is File)
            ListTile(
              leading: const Icon(Icons.file_present_outlined),
              title: const Text('Share file'),
              onTap: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Sharing ${p.basename(entity.path)}',
                    files: [XFile(entity.path)],
                  ),
                );
              },
            ),
          if (entity is Directory)
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('Share as zip'),
              onTap: () async {
                Navigator.pop(ctx);
                final xFiles = await service.zipDirectories([entity]);
                if (xFiles.isNotEmpty) {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: 'Sharing ${p.basename(entity.path)}',
                      files: xFiles,
                    ),
                  );
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Properties'),
            onTap: () {
              Navigator.pop(ctx);
              _showPropertiesDialog(context, entity, service, syncTracker);
            },
          ),
        ],
      ),
    ),
  );
}

void _showPropertiesDialog(
  BuildContext context,
  FileSystemEntity entity,
  FileExplorerService service,
  SyncTracker? syncTracker,
) {
  showDialog(
    context: context,
    builder: (ctx) => _PropertiesDialog(
      entity: entity,
      service: service,
      syncTracker: syncTracker,
    ),
  );
}

class _PropertiesDialog extends StatefulWidget {
  final FileSystemEntity entity;
  final FileExplorerService service;
  final SyncTracker? syncTracker;

  const _PropertiesDialog({
    required this.entity,
    required this.service,
    this.syncTracker,
  });

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  int? _size;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    _loadSize();
    if (widget.entity is Directory &&
        widget.service.isSyncedSource(widget.entity.path)) {
      _loadConfig();
    }
  }

  Future<void> _loadSize() async {
    final size = widget.entity is Directory
        ? await widget.service.getFolderSize(widget.entity.path)
        : (widget.entity as File).lengthSync();
    if (mounted) setState(() => _size = size);
  }

  Future<void> _loadConfig() async {
    try {
      final store = SourceStore();
      final config = await store.read(Directory(widget.entity.path));
      if (mounted) setState(() => _config = config.toJson());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDir = widget.entity is Directory;
    final name = p.basename(widget.entity.path);
    final stat = widget.entity.statSync();
    final modified = stat.modified;

    final rows = <Widget>[
      _propRow('Name', name),
      _propRow('Type', isDir ? 'Folder' : FileTypeInfo.classify(name).label),
      _propRow(
        'Size',
        _size == null ? '...' : widget.service.formatSize(_size!),
      ),
      _propRow('Location', widget.entity.path),
      _propRow(
        'Modified',
        '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}',
      ),
    ];

    return AlertDialog(
      title: const Text('Properties'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.syncTracker != null && isDir)
              ValueListenableBuilder<Map<String, SyncProgress>>(
                valueListenable: widget.syncTracker!.progress,
                builder: (context, syncProgress, _) {
                  final progress = syncProgress[widget.entity.path];
                  if (progress == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress.progress,
                          minHeight: 4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          syncProgressText(progress),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ...rows,
            if (_config != null) ...[
              const Divider(height: 24),
              _propRow('Type', _config!['type']?.toString() ?? '-'),
              _propRow('URL', _config!['url']?.toString() ?? '-'),
              _propRow('Branch', _config!['default_branch']?.toString() ?? '-'),
              _propRow('Status', _config!['sync_status']?.toString() ?? '-'),
              _propRow('Checkpoint', _config!['checkpoint']?.toString() ?? '-'),
              if (_config!['last_synced_at'] != null)
                _propRow(
                  'Last Synced',
                  _formatIsoDate(_config!['last_synced_at'] as String),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _propRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: _labelStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatIsoDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
