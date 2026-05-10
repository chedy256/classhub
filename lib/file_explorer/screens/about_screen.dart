import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/version.dart';
import '../../core/services/update_checker.dart';
import '../../core/services/update_installer.dart';

enum _UpdateState { checking, available, downloading, installing, error, none }

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  UpdateInfo? _updateInfo;
  _UpdateState _updateState = _UpdateState.checking;
  double _downloadProgress = 0.0;
  String? _errorMessage;

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
        _updateState = info != null ? _UpdateState.available : _UpdateState.none;
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_updateInfo == null) return;

    setState(() {
      _updateState = _UpdateState.downloading;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    final installer = UpdateInstaller();

    final path = await installer.downloadApk(
      _updateInfo!.apkUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      },
    );
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _updateState = _UpdateState.error;
        _errorMessage = 'Download failed. Tap to retry.';
      });
      return;
    }

    setState(() => _updateState = _UpdateState.installing);

    final installed = await installer.install(path);

    if (mounted) {
      if (installed) {
        setState(() => _updateState = _UpdateState.available);
      } else {
        setState(() {
          _updateState = _UpdateState.error;
          _errorMessage = 'Install permission denied. Enable "Install unknown apps" for ClassHub in Settings and try again.';
        });
      }
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
              if (_updateInfo != null && _updateState == _UpdateState.available) ...[
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
          if (_updateState == _UpdateState.available) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _downloadAndInstall,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & Install'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_updateState == _UpdateState.downloading) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloading update...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgress * 100).toInt()}% downloaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_updateState == _UpdateState.installing) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opening installer...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
          ],
          if (_updateState == _UpdateState.error) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorMessage ?? 'Download failed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _downloadAndInstall,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_updateInfo != null && _updateState == _UpdateState.available) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('View release on GitHub'),
              subtitle: Text('v${_updateInfo!.latestVersion}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openUrl(_updateInfo!.releaseUrl),
            ),
          ],
        ],
      ),
    );
  }

  bool get _checking => _updateState == _UpdateState.checking;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
