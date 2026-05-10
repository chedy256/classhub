import 'package:flutter/material.dart';
import 'package:classhub/core/services/classhub_storage_service.dart';
import 'package:classhub/core/services/storage_permission_service.dart';
import 'package:classhub/onboarding/services/onboarding_service.dart';
import 'package:classhub/file_explorer/screens/main_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FolderSelectionWrapper(
        onComplete: (path) => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              rootPath: path,
              initialThemeMode: ThemeMode.system,
            ),
          ),
        ),
      ),
    );
  }
}

class FolderSelectionWrapper extends StatefulWidget {
  final void Function(String path) onComplete;
  const FolderSelectionWrapper({super.key, required this.onComplete});

  @override
  State<FolderSelectionWrapper> createState() => _FolderSelectionWrapperState();
}

class _FolderSelectionWrapperState extends State<FolderSelectionWrapper> {
  String? _selectedPath;
  bool _isLoading = false;
  bool _isCompleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await ClasshubStorageService.getPath();
    if (saved != null && mounted) {
      setState(() => _selectedPath = saved);
    } else {
      final defaultPath = await ClasshubStorageService.getDefaultPath();
      if (mounted) setState(() => _selectedPath = defaultPath);
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final path = await OnboardingService.pickFolder();
    if (!mounted) return;

    if (path == null) {
      setState(() => _isLoading = false);
      return;
    }

    final valid = await OnboardingService.validatePath(path);
    if (!mounted) return;

    setState(() {
      _selectedPath = valid ? path : null;
      _isLoading = false;
      if (!valid) _error = 'Selected path does not exist.';
    });
  }

  Future<void> _completeSetup() async {
    setState(() {
      _isCompleting = true;
      _error = null;
    });

    final hasPermission = await StoragePermissionService.requestPermission();
    if (!hasPermission) {
      setState(() {
        _isCompleting = false;
        _error = 'Storage permission is required.';
      });
      return;
    }

    if (!mounted) return;

    ClasshubStorageService.savePath(_selectedPath!);
    widget.onComplete(_selectedPath!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFolder = _selectedPath != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              color: colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 24),
            Text(
              "Let's Go!",
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a folder for ClassHub to store your files.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedPath ?? 'No folder selected',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFolder,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasFolder ? Icons.check : Icons.folder_open_outlined,
                        size: 18,
                      ),
                label: Text(hasFolder ? 'Change Folder' : 'Select Folder'),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasFolder && !_isCompleting
                    ? () => _completeSetup()
                    : null,
                child: _isCompleting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finish'),
              ),
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}
