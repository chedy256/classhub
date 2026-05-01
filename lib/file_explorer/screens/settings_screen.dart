import 'package:classhub/core/services/classhub_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;

  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentPath = '';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final path = await ClasshubStorageService.getPath();
    final theme = await ClasshubStorageService.getThemeMode();
    setState(() {
      _currentPath = path ?? '';
      _themeMode = theme;
    });
  }

  Future<void> _changePath() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      await ClasshubStorageService.savePath(path);
      setState(() => _currentPath = path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Storage path updated')));
      }
    }
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    debugPrint('[Settings] _changeTheme: mode=$mode');
    await ClasshubStorageService.saveThemeMode(mode);
    setState(() => _themeMode = mode);
    debugPrint('[Settings] calling onThemeChanged callback');
    widget.onThemeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (selection) {
                    _changeTheme(selection.first);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Storage location'),
            subtitle: Text(
              _currentPath,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePath,
          ),
          const Divider(),
        ],
      ),
    );
  }
}
