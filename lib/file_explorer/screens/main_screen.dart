import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import '../../pdf_viewer/pdf_viewer_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sync_engine/sync_engine.dart';
import '../../core/services/sync_tracker.dart';
import '../models/file_type_info.dart';
import '../services/directory_watcher.dart';
import '../services/file_explorer_service.dart';
import '../services/trash_service.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';
import 'package:classhub/share/screens/add_screen.dart';
import 'package:classhub/share/services/deep_link_service.dart';
import '../../core/version.dart';
import '../../core/services/update_checker.dart';
import '../../core/services/changelog_service.dart';
import '../../core/services/classhub_storage_service.dart';
import '../models/source_type_icon.dart';
import '../services/sync_utils.dart';

part 'main_screen_inside_folder.dart';
part 'main_screen_widgets.dart';
part 'main_screen_entity_menu.dart';

class MainScreen extends StatefulWidget {
  final String rootPath;
  final ThemeMode initialThemeMode;

  const MainScreen({
    super.key,
    required this.rootPath,
    required this.initialThemeMode,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  bool _isSelecting = false;

  final Set<int> _selectedIndices = {};
  late AnimationController _fabAnimController;
  late Animation<double> _fabAnimation;

  final FileExplorerService _fileExplorerService = FileExplorerService();
  final TrashService _trashService = TrashService();
  final LinkService _linkService = LinkService();

  String get _shareLabel {
    final hasFiles = _selectedIndices.any((i) => _entries[i] is File);
    if (hasFiles) return 'Share files';
    final onlySources = _selectedIndices.every((i) {
      final e = _entries[i];
      return e is Directory && _fileExplorerService.isSyncedSource(e.path);
    });
    return onlySources && _selectedIndices.isNotEmpty
        ? 'Share sources'
        : 'Share content';
  }

  final SyncTracker _syncTracker = SyncTracker();
  late DirectoryWatcher _watcher;
  List<FileSystemEntity> _entries = [];
  UpdateInfo? _updateInfo;

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
    _loadEntries();
    _initDeepLinks();
    _watcher = DirectoryWatcher(path: widget.rootPath, onChanged: _loadEntries);
    _watcher.start();
    _recoverInterruptedSyncs();
    _cleanupTempFiles();
    _checkForUpdate();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showWhatsNewIfNeeded(),
    );
  }

  Future<void> _cleanupTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final entries = dir.listSync();
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.zip')) {
          try {
            entry.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _showWhatsNewIfNeeded() async {
    final lastSeen = await ClasshubStorageService.getLastSeenVersion();
    if (lastSeen == appVersion) {
      return;
    } else if (lastSeen == null) {
      await ClasshubStorageService.saveLastSeenVersion(appVersion);
      return;
    }
    await ClasshubStorageService.saveLastSeenVersion(appVersion);

    final changelog = await loadFullChangelog();
    if (changelog.isEmpty || !mounted) return;

    showWhatsNewDialog(context, appVersion, changelog);
  }

  Future<void> _checkForUpdate() async {
    final lastCheck = await ClasshubStorageService.getLastUpdateCheck();
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(hours: 6)) {
      return;
    }

    await ClasshubStorageService.saveLastUpdateCheck(DateTime.now());
    final info = await checkForUpdate();
    if (mounted) {
      setState(() => _updateInfo = info);
    }
  }

  Future<void> _recoverInterruptedSyncs() async {
    final staleSources = await SyncEngine.detectStaleSyncs(
      Directory(widget.rootPath),
    );
    if (staleSources.isEmpty) return;

    final names = staleSources.map((d) => p.basename(d.path)).toList();
    final joined = names.join(', ');
    if (!mounted) return;

    final lockService = LockService();
    for (final source in staleSources) {
      final name = p.basename(source.path);
      await lockService.deleteLock(Directory(widget.rootPath), name);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resuming downloads: $joined'),
        duration: const Duration(seconds: 3),
      ),
    );

    for (final source in staleSources) {
      _syncSource(source);
    }
  }

  void _initDeepLinks() {
    _linkService.linkStream.listen((uri) {
      final urls = _linkService.extractAddUrls(uri);
      if (urls.isNotEmpty && mounted) {
        _openAddScreen(urls);
      }
    });
  }

  Future<void> _openAddScreen(List<String> urls) async {
    final selectedUrls = await showDialog<List<String>>(
      context: context,
      builder: (_) => AddSourceDialog(incomingUrls: urls),
    );
    if (selectedUrls != null && mounted) {
      await Future.wait(selectedUrls.map(_addSingleSource));
    }
  }

  Future<void> _addSource() async {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabAnimController.reverse();
      });
    }
    final selectedUrls = await showDialog<List<String>>(
      context: context,
      builder: (_) => const AddSourceDialog(),
    );
    if (selectedUrls != null && mounted) {
      await Future.wait(selectedUrls.map(_addSingleSource));
    }
  }

  Future<void> _addSingleSource(String url) async {
    final repoName = _getRepoName(url);
    final repoPath = p.join(widget.rootPath, repoName);
    var firstProgress = true;

    final trackerCallback = _syncTracker.start(repoPath);
    final syncEngine = SyncEngine(
      appFolder: Directory(widget.rootPath),
      githubToken: await ClasshubStorageService.getGithubToken(),
      onProgress: (progress) {
        if (!mounted) return;
        if (firstProgress) {
          firstProgress = false;
          _loadEntries();
        }
        trackerCallback(progress);
      },
    );
    final result = await syncEngine.addSource(url);
    _syncTracker.stop();
    _syncTracker.clearProgress(repoPath);
    if (!mounted) return;
    _loadEntries();
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$repoName: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesDeleted} deleted',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$repoName: ${result.error}')));
    }
  }

  String _getRepoName(String url) {
    try {
      return getSourceFolderName(url);
    } catch (_) {
      return url;
    }
  }

  Future<void> _syncSource(Directory sourceDir) async {
    await performSync(
      sourceDir: sourceDir,
      rootPath: widget.rootPath,
      syncTracker: _syncTracker,
      context: context,
      onAfterSync: _loadEntries,
      onSuccess: (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced ${p.basename(sourceDir.path)}: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesDeleted} deleted',
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _watcher.stop();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _loadEntries() {
    setState(() {
      _entries = _fileExplorerService.loadEntries(widget.rootPath);
      _selectedIndices.clear();
      if (_entries.isEmpty) _isSelecting = false;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
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
                _fileExplorerService.createFolder(widget.rootPath, name);
                _loadEntries();
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
                  _fileExplorerService.createFolder(widget.rootPath, name);
                  _loadEntries();
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
      _fileExplorerService.uploadFilesToFolder(widget.rootPath, paths);
      _loadEntries();
    }
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
      if (_selectedIndices.length == _entries.length) {
        _selectedIndices.clear();
        _isSelecting = false;
      } else {
        _selectedIndices.addAll(List.generate(_entries.length, (i) => i));
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelecting = false;
    });
  }

  void _deleteSelected() {
    final toDelete = _selectedIndices.map((i) => _entries[i]).toList();
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
              _loadEntries();
            },
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelected() async {
    final selected = _selectedIndices.map((i) => _entries[i]).toList();
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
      await _linkService.shareSheet(urls);
    } else {
      final xFiles = await _fileExplorerService.zipDirectories(dirs);
      await SharePlus.instance.share(ShareParams(files: xFiles));
    }
    _cancelSelection();
  }

  void _showItemMenu(FileSystemEntity entity) {
    _showEntityMenu(
      context,
      entity,
      _fileExplorerService,
      _loadEntries,
      rootPath: widget.rootPath,
      trashService: _trashService,
      onSync:
          entity is Directory &&
              _fileExplorerService.isSyncedSource(entity.path)
          ? () => _syncSource(entity)
          : null,
      syncTracker: _syncTracker,
    );
  }

  Future<void> _openSearch() async {
    final selectedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(rootPath: widget.rootPath),
      ),
    );
    if (!mounted || selectedPath == null) return;
    final type = FileSystemEntity.typeSync(selectedPath);
    if (type == FileSystemEntityType.directory) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _InsideFolderScreen(
            folderPath: selectedPath,
            rootPath: widget.rootPath,
            isInsideSource: _fileExplorerService.isInsideSource(
              selectedPath,
              widget.rootPath,
            ),
            syncTracker: _syncTracker,
          ),
        ),
      );
      if (mounted) _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Text(
                  'ClassHub',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        initialThemeMode: widget.initialThemeMode,
                      ),
                    ),
                  );
                },
              ),
              _DrawerItem(
                icon: Icons.delete_outlined,
                label: 'Trash',
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrashScreen(rootPath: widget.rootPath),
                    ),
                  );
                  _loadEntries();
                },
              ),
              _DrawerItem(
                icon: Icons.support,
                label: 'Support',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  );
                },
              ),
              _DrawerItem(
                icon: Icons.info,
                label: 'About',
                showBadge: _updateInfo != null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: _isSelecting
            ? IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurface),
                onPressed: _cancelSelection,
              )
            : Builder(
                builder: (ctx) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: colorScheme.onSurface),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                    if (_updateInfo != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        title: _isSelecting
            ? Text('${_selectedIndices.length} selected')
            : const Text('ClassHub'),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _entries.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: _selectedIndices.length == _entries.length
                      ? 'Deselect all'
                      : 'Select all',
                  onPressed: _selectAll,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
              ],
      ),
      bottomNavigationBar: _isSelecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
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
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _shareSelected,
                        icon: const Icon(Icons.share),
                        label: Text(_shareLabel),
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
            onRefresh: () async => _loadEntries(),
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open,
                          color: colorScheme.onSurfaceVariant,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ValueListenableBuilder<Map<String, SyncProgress>>(
                    valueListenable: _syncTracker.progress,
                    builder: (context, syncProgress, _) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entity = _entries[index];
                          final isDir = entity is Directory;
                          final name = p.basename(entity.path);
                          final isSelected = _selectedIndices.contains(index);
                          final progress = syncProgress[entity.path];
                          final sourceConfig = isDir
                              ? _fileExplorerService.getSourceConfig(
                                  entity.path,
                                )
                              : null;

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
                                            isInsideSource: _fileExplorerService
                                                .isInsideSource(
                                                  entity.path,
                                                  widget.rootPath,
                                                ),
                                            syncTracker: _syncTracker,
                                          ),
                                        ),
                                      );
                                      _loadEntries();
                                    }
                                  : () {
                                      if (entity.path.toLowerCase().endsWith('.pdf')) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PdfViewerPage(
                                              filePath: entity.path,
                                              title: p.basename(entity.path),
                                            ),
                                          ),
                                        );
                                      } else {
                                        OpenFile.open(entity.path);
                                      }
                                    },
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
                                      child: sourceConfig != null
                                          ? sourceConfig.type.iconWidget(
                                              size: 24,
                                              color: colorScheme
                                                  .onPrimaryContainer,
                                            )
                                          : Icon(
                                              isDir
                                                  ? Icons.folder_outlined
                                                  : FileTypeInfo.classify(
                                                      name,
                                                    ).icon,
                                              size: 24,
                                              color: colorScheme
                                                  .onPrimaryContainer,
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
                                          if (progress != null) ...[
                                            LinearProgressIndicator(
                                              value: progress.progress,
                                              minHeight: 3,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              syncProgressText(progress),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme.primary,
                                                  ),
                                            ),
                                          ] else if (sourceConfig != null)
                                            Text(
                                              _fileExplorerService
                                                      .formatLastSynced(
                                                        sourceConfig
                                                            .lastSyncedAt,
                                                      ) ??
                                                  'Not synced',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            )
                                          else
                                            Text(
                                              _fileExplorerService
                                                  .entitySubtitle(entity),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelecting)
                                      IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () => _showItemMenu(entity),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_isFabExpanded && !_isSelecting)
            GestureDetector(
              onTap: _toggleFab,
              child: Container(color: Colors.black54),
            ),
          if (!_isSelecting)
            Positioned(
              right: 16,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fabAnimation,
                    child: ScaleTransition(
                      scale: _fabAnimation,
                      alignment: Alignment.bottomRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FabOption(
                            label: 'Source',
                            icon: Icons.wifi_tethering,
                            onTap: _addSource,
                          ),
                          const SizedBox(height: 10),
                          _FabOption(
                            label: 'Files',
                            icon: Icons.upload_file_outlined,
                            onTap: _uploadFiles,
                          ),
                          const SizedBox(height: 10),
                          _FabOption(
                            label: 'Folder',
                            icon: Icons.create_new_folder_outlined,
                            onTap: _createFolder,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleFab,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _isFabExpanded ? 52 : 56,
                      height: _isFabExpanded ? 52 : 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          _isFabExpanded ? 26 : 16,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _isFabExpanded ? 0.125 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          _isFabExpanded ? Icons.close : Icons.add,
                          color: colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
