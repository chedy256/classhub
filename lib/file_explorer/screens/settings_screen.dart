import 'package:flutter/material.dart';
import 'package:classhub/core/services/classhub_path_service.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final path = await ClasshubPathService.getPath();
    setState(() => _currentPath = path);
  }

  Future<void> _changePath() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      await ClasshubPathService.savePath(path);
      setState(() => _currentPath = path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage path updated')),
        );
      }
    }
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
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Storage location'),
            subtitle: Text(_currentPath),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePath,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _AboutRoute()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutRoute extends StatelessWidget {
  const _AboutRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_copy, size: 80),
            SizedBox(height: 24),
            Text(
              'ClassHub',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
          ],
        ),
      ),
    );
  }
}