import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.support,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Support',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Report a bug'),
            subtitle: const Text('GitHub Issues'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl('https://github.com/titanknis/classhub/issues'),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share app'),
            subtitle: const Text('Send to friends'),
            trailing: const Icon(Icons.share_outlined),
            onTap: _shareApp,
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out ClassHub: https://classhub.knisium.com',
      subject: 'ClassHub',
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
