import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/version.dart';
import '../../core/services/update_checker.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  UpdateInfo? _updateInfo;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final info = await checkForUpdate();
    if (mounted) {
      setState(() {
        _updateInfo = info;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Text(
            'ClassHub',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Text(
                'Version $appVersion',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_updateInfo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Update available: ${_updateInfo!.latestVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_checking) ...[
                const SizedBox(height: 4),
                Text(
                  'Checking for updates...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            subtitle: const Text('GitHub repository'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://github.com/titanknis/classhub'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Website'),
            subtitle: const Text('classhub.knisium.com'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://classhub.knisium.com'),
          ),
          if (_updateInfo != null)
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download latest version'),
              subtitle: Text('Get ${_updateInfo!.latestVersion} from GitHub'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUrl(_updateInfo!.releaseUrl),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
