part of 'main_screen.dart';

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
  final bool showBadge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (showBadge)
            Positioned(
              right: -4,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
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
  final VoidCallback onAddFiles;
  final VoidCallback onCreateFolder;
  final ColorScheme colorScheme;

  const _RegularFab({
    required this.isFabExpanded,
    required this.fabAnimController,
    required this.fabAnimation,
    required this.onToggle,
    required this.onAddFiles,
    required this.onCreateFolder,
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
                  label: 'Files',
                  icon: Icons.upload_file_outlined,
                  onTap: onAddFiles,
                ),
                const SizedBox(height: 10),
                _FabOption(
                  label: 'Folder',
                  icon: Icons.create_new_folder_outlined,
                  onTap: onCreateFolder,
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
