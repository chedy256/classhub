import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import '../models/file_type_info.dart';
import '../services/file_explorer_service.dart';
import '../services/trash_service.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';

class MainScreen extends StatefulWidget {
  final String rootPath;

  const MainScreen({super.key, required this.rootPath});

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

  void _addSource() {
    _toggleFab();
    // TODO: handle adding source
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
        backgroundColor: const Color(0xFF151822),
        title: const Text(
          'Move to Trash',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${toDelete.length} item${toDelete.length > 1 ? 's' : ''}  will be deleted after 30 days.',
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
              for (final entity in toDelete) {
                _trashService.moveToTrash(widget.rootPath, entity);
              }
              _loadEntries();
            },
            child: const Text(
              'Move to trash',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
          ),
        ),
      );
      if (mounted) _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF090C14);
    const cardColor = Color(0xFF111827);
    const accentBlue = Color(0xFF80A3FF);
    const subtitleColor = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F1420),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Text(
                  'ClassHub',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24)),
              const Divider(color: Color(0xFF1F2937), height: 0),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
              const Divider(color: Color(0xFF1F2937), height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: subtitleColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _cancelSelection,
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: _isSelecting
            ? Text(
                '${_selectedIndices.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const Text(
                'Classhub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _entries.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: accentBlue,
                  ),
                  tooltip: _selectedIndices.length == _entries.length
                      ? 'Deselect all'
                      : 'Select all',
                  onPressed: _selectAll,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Color.fromARGB(255, 180, 180, 180),
                  ),
                  onPressed: _openSearch,
                ),
              ],
      ),
      bottomNavigationBar: _isSelecting
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _deleteSelected,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Move to trash'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
      body: Stack(
        children: [
          // Entry list
          _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open,
                        color: subtitleColor.withValues(alpha: 0.4),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No items yet',
                        style: TextStyle(color: subtitleColor, fontSize: 14),
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

                    return Material(
                      color: isSelected
                          ? accentBlue.withValues(alpha: 0.10)
                          : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        splashColor: accentBlue.withValues(alpha: 0.08),
                        highlightColor: accentBlue.withValues(alpha: 0.05),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? accentBlue.withValues(alpha: 0.4)
                                  : const Color(0xFF1F2937),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isSelecting) ...[
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? accentBlue
                                      : subtitleColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: accentBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDir
                                      ? Icons.folder_outlined
                                      : Icons.description_outlined,
                                  color: accentBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
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
                                    Text(
                                      _fileExplorerService.entitySubtitle(
                                        entity,
                                      ),
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isSelecting)
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Color(0xFF6B7280),
                                      size: 20,
                                    ),
                                    onPressed: () => _showItemMenu(entity),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

          // Scrim when FAB is expanded
          if (_isFabExpanded && !_isSelecting)
            GestureDetector(
              onTap: _toggleFab,
              child: Container(color: Colors.black54),
            ),

          // Expanded FAB options
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
                  // Main FAB
                  GestureDetector(
                    onTap: _toggleFab,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _isFabExpanded ? 52 : 56,
                      height: _isFabExpanded ? 52 : 56,
                      decoration: BoxDecoration(
                        color: accentBlue,
                        borderRadius: BorderRadius.circular(
                          _isFabExpanded ? 26 : 16,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _isFabExpanded ? 0.125 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          _isFabExpanded ? Icons.close : Icons.add,
                          color: const Color(0xFF090C14),
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

// --- Widgets ---

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2236),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF80A3FF), size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF80A3FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drawer item ───

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
    const accentBlue = Color(0xFF80A3FF);

    return ListTile(
      leading: Icon(icon, color: accentBlue, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: onTap,
    );
  }
}

// Inside-folder screen — files only, single + FAB
class _InsideFolderScreen extends StatefulWidget {
  final String folderPath;
  final String rootPath;
  const _InsideFolderScreen({required this.folderPath, required this.rootPath});

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
        backgroundColor: const Color(0xFF151822),
        title: const Text(
          'Move to Trash',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${toDelete.length} item${toDelete.length > 1 ? 's' : ''} will be deleted after 30 days.',
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
              for (final entity in toDelete) {
                _trashService.moveToTrash(widget.rootPath, entity);
              }
              _loadFiles();
            },
            child: const Text(
              'Move to trash',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF090C14);
    const accentBlue = Color(0xFF80A3FF);
    const subtitleColor = Color(0xFF6B7280);
    const cardColor = Color(0xFF111827);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            _isSelecting ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: _isSelecting
              ? _cancelSelection
              : () => Navigator.pop(context),
        ),
        title: _isSelecting
            ? Text(
                '${_selectedIndices.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                p.basename(widget.folderPath),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    _selectedIndices.length == _files.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: accentBlue,
                  ),
                  tooltip: _selectedIndices.length == _files.length
                      ? 'Deselect all'
                      : 'Select all',
                  onPressed: _selectAll,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _isSelecting
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _deleteSelected,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Move to trash'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
      body: Stack(
        children: [
          _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        color: subtitleColor.withValues(alpha: 0.4),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No files yet \u2014 tap + to upload',
                        style: TextStyle(color: subtitleColor, fontSize: 14),
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

                    return Material(
                      color: isSelected
                          ? accentBlue.withValues(alpha: 0.10)
                          : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        splashColor: accentBlue.withValues(alpha: 0.08),
                        highlightColor: accentBlue.withValues(alpha: 0.05),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? accentBlue.withValues(alpha: 0.4)
                                  : const Color(0xFF1F2937),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isSelecting) ...[
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? accentBlue
                                      : subtitleColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: accentBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  info.icon,
                                  color: accentBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
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
                                    Text(
                                      isDir
                                          ? _fileExplorerService.entitySubtitle(
                                              entity,
                                            )
                                          : sizeStr.isNotEmpty
                                          ? '${info.label} \u2022 $sizeStr'
                                          : info.label,
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isSelecting)
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Color(0xFF6B7280),
                                      size: 20,
                                    ),
                                    onPressed: () => _showFileMenu(entity),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          // Scrim when FAB is expanded
          if (_isFabExpanded && !_isSelecting)
            GestureDetector(
              onTap: _toggleFab,
              child: Container(color: Colors.black54),
            ),
          // Expanding FAB
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
                            label: 'Upload folder',
                            icon: Icons.drive_folder_upload_outlined,
                            onTap: _uploadFolder,
                          ),
                          const SizedBox(height: 10),
                          _FabOption(
                            label: 'Upload files',
                            icon: Icons.upload_file_outlined,
                            onTap: _uploadFiles,
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
                        color: accentBlue,
                        borderRadius: BorderRadius.circular(
                          _isFabExpanded ? 26 : 16,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _isFabExpanded ? 0.125 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          _isFabExpanded ? Icons.close : Icons.add,
                          color: const Color(0xFF090C14),
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

// ─── Shared helpers ───

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
      backgroundColor: const Color(0xFF151822),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF80A3FF)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF80A3FF)),
          ),
        ),
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
            leading: const Icon(Icons.edit_outlined, color: Color(0xFF80A3FF)),
            title: const Text('Rename', style: TextStyle(color: Colors.white)),
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
          ListTile(
            leading: const Icon(Icons.copy_outlined, color: Color(0xFF80A3FF)),
            title: const Text(
              'Copy path',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: entity.path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Path copied to clipboard')),
              );
            },
          ),
        ],
      ),
    ),
  );
}
