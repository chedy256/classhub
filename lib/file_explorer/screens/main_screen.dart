import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:sync_engine/sync_engine.dart';
import '../models/file_type_info.dart';
import '../services/file_explorer_service.dart';
import '../services/trash_service.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';
import 'package:classhub/share/screens/add_screen.dart';
import 'package:classhub/share/services/deep_link_service.dart';

class MainScreen extends StatefulWidget {
  final String rootPath;
  final void Function(ThemeMode)? onThemeChanged;

  const MainScreen({
    super.key,
    required this.rootPath,
    this.onThemeChanged,
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
  List<FileSystemEntity> _entries = [];

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
  }

  void _initDeepLinks() {
    _linkService.linkStream.listen((uri) {
      final urls = _linkService.extractAddUrls(uri);
      if (urls.isNotEmpty && mounted) {
        _openAddScreen(urls);
      }
    });
  }

  void _openAddScreen(List<String> urls) {
    showDialog(
      context: context,
      builder: (_) => AddSourceDialog(
        incomingUrls: urls,
        rootPath: widget.rootPath,
        onAdded: _loadEntries,
      ),
    );
  }

  void _addSource() {
    showDialog(
      context: context,
      builder: (_) =>
          AddSourceDialog(rootPath: widget.rootPath, onAdded: _loadEntries),
    );
  }

  @override
  void dispose() {
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

  Future<void> _createFolder() async {
    _toggleFab();
    final name = await _showTextInputDialog(
      context,
      'New Folder',
      'Folder name',
      'Create',
    );
    if (name != null && name.isNotEmpty) {
      _fileExplorerService.createFolder(widget.rootPath, name);
      _loadEntries();
    }
  }

  Future<void> _uploadFolder() async {
    _toggleFab();
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      _fileExplorerService.copyFolderTo(widget.rootPath, path);
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
    final toShare = _selectedIndices
        .map((i) => _entries[i])
        .whereType<Directory>()
        .where((d) => _fileExplorerService.isSyncedSource(d.path))
        .toList();

    final urls = <String>[];
    for (final dir in toShare) {
      final url = _fileExplorerService.getSourceUrl(dir.path);
      if (url != null) urls.add(url);
    }

    if (urls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aucun source sélectionné')));
      return;
    }

    await _linkService.shareSheet(urls);
  }

  void _showItemMenu(FileSystemEntity entity) {
    _showEntityMenu(context, entity, _fileExplorerService, _loadEntries);
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
            isSynced: _fileExplorerService.isSyncedSource(selectedPath),
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
                      builder: (_) =>
                          SettingsScreen(onThemeChanged: widget.onThemeChanged),
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
                icon: Icons.favorite,
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
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu, color: colorScheme.onSurface),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
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
                            : _shareSelected,
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _deleteSelected,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Move to trash'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          _entries.isEmpty
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
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entity = _entries[index];
                    final isDir = entity is Directory;
                    final name = p.basename(entity.path);
                    final isSelected = _selectedIndices.contains(index);

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
                                      isSynced: _fileExplorerService
                                          .isSyncedSource(entity.path),
                                    ),
                                  ),
                                );
                                _loadEntries();
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
                                  isDir
                                      ? Icons.folder_outlined
                                      : Icons.description_outlined,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      _fileExplorerService.entitySubtitle(entity),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
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
                            label: 'Upload',
                            icon: Icons.drive_folder_upload_outlined,
                            onTap: _uploadFolder,
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

class _FabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FabOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: onTap,
    );
  }
}

class _SyncedFab extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const _SyncedFab({required this.isSyncing, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isSyncing ? null : onSync,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isSyncing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimaryContainer,
                  ),
                )
              : Icon(
                  Icons.sync,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
        ),
      ),
    );
  }
}

class _RegularFab extends StatelessWidget {
  final bool isFabExpanded;
  final AnimationController fabAnimController;
  final Animation<double> fabAnimation;
  final VoidCallback onToggle;
  final VoidCallback onUploadFiles;
  final VoidCallback onUploadFolder;
  final ColorScheme colorScheme;

  const _RegularFab({
    required this.isFabExpanded,
    required this.fabAnimController,
    required this.fabAnimation,
    required this.onToggle,
    required this.onUploadFiles,
    required this.onUploadFolder,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: fabAnimation,
          child: ScaleTransition(
            scale: fabAnimation,
            alignment: Alignment.bottomRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FabOption(
                  label: 'Upload folder',
                  icon: Icons.drive_folder_upload_outlined,
                  onTap: onUploadFolder,
                ),
                const SizedBox(height: 10),
                _FabOption(
                  label: 'Upload files',
                  icon: Icons.upload_file_outlined,
                  onTap: onUploadFiles,
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isFabExpanded ? 52 : 56,
            height: isFabExpanded ? 52 : 56,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(isFabExpanded ? 26 : 16),
            ),
            child: AnimatedRotation(
              turns: isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isFabExpanded ? Icons.close : Icons.add,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsideFolderScreen extends StatefulWidget {
  final String folderPath;
  final String rootPath;
  final bool isSynced;

  const _InsideFolderScreen({
    required this.folderPath,
    required this.rootPath,
    this.isSynced = false,
  });

  @override
  State<_InsideFolderScreen> createState() => _InsideFolderScreenState();
}

class _InsideFolderScreenState extends State<_InsideFolderScreen>
    with SingleTickerProviderStateMixin {
  final FileExplorerService _fileExplorerService = FileExplorerService();
  final TrashService _trashService = TrashService();
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
  }

  @override
  void dispose() {
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

  Future<void> _uploadFiles() async {
    _toggleFab();
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((pf) => pf.path != null)
          .map((pf) => pf.path!)
          .toList();
      _fileExplorerService.uploadFilesToFolder(widget.folderPath, paths);
      _loadFiles();
    }
  }

  Future<void> _uploadFolder() async {
    _toggleFab();
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      _fileExplorerService.copyFolderTo(widget.folderPath, path);
      _loadFiles();
    }
  }

  Future<void> _syncSource() async {
    setState(() => _isSyncing = true);
    final syncEngine = SyncEngine(appFolder: Directory(widget.rootPath));
    final result = await syncEngine.syncSource(Directory(widget.folderPath));
    setState(() => _isSyncing = false);
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced: ${result.filesAdded} added, ${result.filesUpdated} updated, ${result.filesDeleted} deleted',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadFiles();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
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
    _showEntityMenu(context, entity, _fileExplorerService, _loadFiles);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_isSelecting ? Icons.close : Icons.arrow_back),
          onPressed: _isSelecting
              ? _cancelSelection
              : () => Navigator.pop(context),
        ),
        title: _isSelecting
            ? Text('${_selectedIndices.length} selected')
            : Text(p.basename(widget.folderPath)),
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
                child: OutlinedButton.icon(
                  onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Move to trash'),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          _files.isEmpty
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          ? _fileExplorerService.entitySubtitle(
                                              entity,
                                            )
                                          : sizeStr.isNotEmpty
                                          ? '${info.label} · $sizeStr'
                                          : info.label,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
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
          if (!_isSelecting)
            Positioned(
              right: 16,
              bottom: 40,
              child: widget.isSynced
                  ? _SyncedFab(isSyncing: _isSyncing, onSync: _syncSource)
                  : _RegularFab(
                      isFabExpanded: _isFabExpanded,
                      fabAnimController: _fabAnimController,
                      fabAnimation: _fabAnimation,
                      onToggle: _toggleFab,
                      onUploadFiles: _uploadFiles,
                      onUploadFolder: _uploadFolder,
                      colorScheme: colorScheme,
                    ),
            ),
        ],
      ),
    );
  }
}

Future<String?> _showTextInputDialog(
  BuildContext context,
  String title,
  String hint,
  String action,
) {
  final controller = TextEditingController();
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
  VoidCallback onRefresh,
) {
  final isSource = entity is Directory && service.isSyncedSource(entity.path);
  final linkService = LinkService();
  final sourceUrl = isSource ? service.getSourceUrl(entity.path) : null;

  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              );
              if (newName != null && newName.isNotEmpty && newName != oldName) {
                service.renameEntity(entity, newName);
                onRefresh();
              }
            },
          ),
          if (sourceUrl != null)
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                linkService.shareSheet([sourceUrl]);
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Properties'),
            onTap: () {
              Navigator.pop(ctx);
              _showPropertiesDialog(context, entity, service);
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
) {
  showDialog(
    context: context,
    builder: (ctx) => _PropertiesDialog(entity: entity, service: service),
  );
}

class _PropertiesDialog extends StatefulWidget {
  final FileSystemEntity entity;
  final FileExplorerService service;

  const _PropertiesDialog({
    required this.entity,
    required this.service,
  });

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
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
            ...rows,
            if (_config != null) ...[
              const Divider(height: 24),
              _propRow('Type', _config!['type']?.toString() ?? '-'),
              _propRow('URL', _config!['url']?.toString() ?? '-'),
              _propRow(
                'Branch',
                _config!['default_branch']?.toString() ?? '-',
              ),
              _propRow(
                'Status',
                _config!['sync_status']?.toString() ?? '-',
              ),
              _propRow(
                'Checkpoint',
                _config!['checkpoint']?.toString() ?? '-',
              ),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
