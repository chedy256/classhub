part of 'main_screen.dart';

class _InsideFolderScreen extends StatefulWidget {
  final String folderPath;
  final String rootPath;
  final bool isInsideSource;
  final SyncTracker? syncTracker;

  const _InsideFolderScreen({
    required this.folderPath,
    required this.rootPath,
    this.isInsideSource = false,
    this.syncTracker,
  });

  @override
  State<_InsideFolderScreen> createState() => _InsideFolderScreenState();
}

class _InsideFolderScreenState extends State<_InsideFolderScreen>
    with SingleTickerProviderStateMixin {
  final FileExplorerService _fileExplorerService = FileExplorerService();
  final TrashService _trashService = TrashService();
  late DirectoryWatcher _watcher;

  String get _insideShareLabel {
    final hasFiles = _selectedIndices.any((i) => _files[i] is File);
    if (hasFiles) return 'Share files';
    final onlySources = _selectedIndices.every((i) {
      final e = _files[i];
      return e is Directory && _fileExplorerService.isSyncedSource(e.path);
    });
    return onlySources && _selectedIndices.isNotEmpty
        ? 'Share sources'
        : 'Share content';
  }

  List<FileSystemEntity> _files = [];
  final Set<int> _selectedIndices = {};
  bool _isSelecting = false;
  bool _isSyncing = false;
  bool _isFabExpanded = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOut,
    );
    _loadFiles();
    _watcher = DirectoryWatcher(path: widget.folderPath, onChanged: _loadFiles);
    _watcher.start();
  }

  @override
  void dispose() {
    _watcher.stop();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _loadFiles() {
    setState(() {
      _files = _fileExplorerService.loadFolderContents(widget.folderPath);
      _selectedIndices.clear();
      if (_files.isEmpty) _isSelecting = false;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      _isFabExpanded
          ? _fabAnimController.forward()
          : _fabAnimController.reverse();
    });
  }

  void _createFolder() {
    _toggleFab();
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
            onSubmitted: (name) {
              if (name.isNotEmpty) {
                _fileExplorerService.createFolder(widget.folderPath, name);
                _loadFiles();
              }
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  _fileExplorerService.createFolder(widget.folderPath, name);
                  _loadFiles();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFiles() async {
    _toggleFab();
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((pf) => pf.path != null)
          .map((pf) => pf.path!)
          .toList();
      _fileExplorerService.uploadFilesToFolder(widget.folderPath, paths);
      _loadFiles();
    }
  }

  Future<void> _syncSource() async {
    setState(() => _isSyncing = true);
    await performSync(
      sourceDir: Directory(widget.folderPath),
      rootPath: widget.rootPath,
      syncTracker: widget.syncTracker,
      context: context,
      onBeforeSync: () {},
      onAfterSync: () {
        if (mounted) setState(() => _isSyncing = false);
        _loadFiles();
      },
      onSuccess: (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced ${p.basename(widget.folderPath)}: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesDeleted} deleted',
            ),
          ),
        );
      },
    );
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
      if (_selectedIndices.length == _files.length) {
        _selectedIndices.clear();
        _isSelecting = false;
      } else {
        _selectedIndices.addAll(List.generate(_files.length, (i) => i));
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelecting = false;
    });
  }

  void _showFileMenu(FileSystemEntity entity) {
    _showEntityMenu(
      context,
      entity,
      _fileExplorerService,
      _loadFiles,
      rootPath: widget.rootPath,
      trashService: _trashService,
      syncTracker: widget.syncTracker,
    );
  }

  void _deleteSelected() {
    final toDelete = _selectedIndices.map((i) => _files[i]).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text(
          '${toDelete.length} item${toDelete.length > 1 ? 's' : ''} will be deleted after 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final entity in toDelete) {
                _trashService.moveToTrash(widget.rootPath, entity);
              }
              _loadFiles();
            },
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelected() async {
    final selected = _selectedIndices.map((i) => _files[i]).toList();
    final files = selected.whereType<File>().toList();
    final dirs = selected.whereType<Directory>().toList();
    final hasFiles = files.isNotEmpty;

    if (hasFiles) {
      final xFiles = <XFile>[
        ...files.map((f) => XFile(f.path)),
        ...await _fileExplorerService.zipDirectories(dirs),
      ];
      await SharePlus.instance.share(ShareParams(files: xFiles));
      _cancelSelection();
      return;
    }

    final sources = dirs
        .where((d) => _fileExplorerService.isSyncedSource(d.path))
        .toList();
    if (sources.length == dirs.length && sources.isNotEmpty) {
      final urls = sources
          .map((d) => _fileExplorerService.getSourceUrl(d.path))
          .whereType<String>()
          .toList();
      if (urls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun source sélectionné')),
          );
        }
        _cancelSelection();
        return;
      }
      final linkService = LinkService();
      await linkService.shareSheet(urls);
    } else {
      final xFiles = await _fileExplorerService.zipDirectories(dirs);
      await SharePlus.instance.share(ShareParams(files: xFiles));
    }
    _cancelSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceConfig = _fileExplorerService.getSourceConfig(
      widget.folderPath,
    );
    final lastSynced = _fileExplorerService.formatLastSynced(
      sourceConfig?.lastSyncedAt,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_isSelecting ? Icons.close : Icons.arrow_back),
          onPressed: _isSelecting
              ? _cancelSelection
              : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    _isSelecting
                        ? '${_selectedIndices.length} selected'
                        : p.basename(widget.folderPath),
                        overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sourceConfig != null && !_isSelecting) ...[
                  const SizedBox(width: 6),
                  sourceConfig.type.iconWidget(
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            ValueListenableBuilder<Map<String, SyncProgress>>(
              valueListenable:
                  widget.syncTracker?.progress ?? ValueNotifier({}),
              builder: (context, syncProgress, _) {
                final progress = syncProgress[widget.folderPath];
                if (progress != null && !_isSelecting) {
                  return Text(
                    syncProgressText(progress),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  );
                } else if (lastSynced != null &&
                    sourceConfig != null &&
                    !_isSelecting) {
                  return Text(
                    'Synced $lastSynced',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _files.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: _selectAll,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _isSelecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (!widget.isInsideSource) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedIndices.isEmpty
                              ? null
                              : _deleteSelected,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Move to trash'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _shareSelected,
                        icon: const Icon(Icons.share),
                        label: Text(_insideShareLabel),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _loadFiles(),
            child: _files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          color: colorScheme.onSurfaceVariant,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No files yet — tap + to upload',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entity = _files[index];
                      final isDir = entity is Directory;
                      final name = p.basename(entity.path);
                      final info = FileTypeInfo.classify(
                        name,
                        isDirectory: isDir,
                      );
                      final isSelected = _selectedIndices.contains(index);

                      String sizeStr = '';
                      if (entity is File) {
                        try {
                          sizeStr = _fileExplorerService.formatSize(
                            entity.lengthSync(),
                          );
                        } catch (_) {}
                      }

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isSelecting
                              ? () => _toggleSelect(index)
                              : isDir
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _InsideFolderScreen(
                                        folderPath: entity.path,
                                        rootPath: widget.rootPath,
                                        isInsideSource:
                                            widget.isInsideSource ||
                                            _fileExplorerService.isInsideSource(
                                              entity.path,
                                              widget.rootPath,
                                            ),
                                        syncTracker: widget.syncTracker,
                                      ),
                                    ),
                                  );
                                  _loadFiles();
                                }
                              : () => OpenFile.open(entity.path),
                          onLongPress: () {
                            if (!_isSelecting) {
                              setState(() {
                                _isSelecting = true;
                                _selectedIndices.add(index);
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                if (_isSelecting) ...[
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    info.icon,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isDir
                                            ? _fileExplorerService
                                                  .entitySubtitle(entity)
                                            : sizeStr.isNotEmpty
                                            ? '${info.label} · $sizeStr'
                                            : info.label,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isSelecting)
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => _showFileMenu(entity),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_isSelecting)
            Positioned(
              right: 16,
              bottom: 40,
              child: widget.isInsideSource
                  ? _SyncedFab(isSyncing: _isSyncing, onSync: _syncSource)
                  : _RegularFab(
                      isFabExpanded: _isFabExpanded,
                      fabAnimController: _fabAnimController,
                      fabAnimation: _fabAnimation,
                      onToggle: _toggleFab,
                      onAddFiles: _uploadFiles,
                      onCreateFolder: _createFolder,
                      colorScheme: colorScheme,
                    ),
            ),
        ],
      ),
    );
  }
}
