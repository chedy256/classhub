import 'package:flutter/material.dart';
import 'package:classhub/onboarding/services/onboarding_service.dart';
import 'package:classhub/file_explorer/screens/main_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FolderSelectionWrapper(
        onComplete: (String path) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainScreen(rootPath: path)),
          );
        },
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingPath();
  }

  Future<void> _loadExistingPath() async {
    final saved = await OnboardingService.loadSavedPath();
    if (saved != null && mounted) {
      setState(() => _selectedPath = saved);
    }
  }

  Future<void> _handlePickFolder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await OnboardingService.pickFolder();
    final hasPermission = result['hasPermission'] as bool;
    final path = result['path'] as String?;

    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Storage permission denied. Please grant it in app settings.';
      });
      return;
    }

    if (path != null) {
      final valid = await OnboardingService.validatePath(path);
      if (!mounted) return;

      if (valid) {
        setState(() {
          _selectedPath = path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Selected path does not exist. Please try again.';
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FolderSelectionScreen(
      selectedPath: _selectedPath,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onPickFolder: _handlePickFolder,
      onNext: _selectedPath != null ? () => widget.onComplete(_selectedPath!) : null,
    );
  }
}

class FolderSelectionScreen extends StatelessWidget {
  final String? selectedPath;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onPickFolder;
  final VoidCallback? onNext;

  const FolderSelectionScreen({
    super.key,
    required this.selectedPath,
    required this.isLoading,
    required this.errorMessage,
    required this.onPickFolder,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool folderSelected = selectedPath != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1523),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.rocket_launch_outlined,
                color: colorScheme.primary,
                size: 40,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome!',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Let's set some things up first. You can always change these in the settings later too.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2333),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a folder where ClassHub will store lessons, files, sources and more.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A dedicated folder is recommended.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                        children: [
                          const TextSpan(text: 'Selected folder: '),
                          TextSpan(
                            text: selectedPath ?? 'No storage location set',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading ? null : onPickFolder,
                        style: FilledButton.styleFrom(
                          backgroundColor: folderSelected
                              ? const Color(0xFF1C2333)
                              : colorScheme.primary,
                          foregroundColor: folderSelected
                              ? Colors.white
                              : colorScheme.onPrimary,
                          side: folderSelected
                              ? const BorderSide(color: Colors.white24)
                              : BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                folderSelected
                                    ? 'Folder selected'
                                    : 'Select a folder',
                              ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: onNext != null
                        ? colorScheme.primary
                        : const Color(0xFF1C2333),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}