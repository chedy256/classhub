import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class LandingPage2 extends StatelessWidget {
  const LandingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ClassHub',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _FeatureCard(
                    title: 'Local Repository Sync',
                    description: 'Manage files with Git-like efficiency',
                    icon: Icons.account_tree_outlined,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    title: 'Instant Indexing',
                    description: 'Search across all your local semesters.',
                    icon: Icons.speed_outlined,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    title: 'Offline First',
                    description: 'Works entirely on your machine.',
                    icon: Icons.cloud_off_outlined,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    title: 'Privacy Guaranteed',
                    description: 'Your data stays on your device.',
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 60),

                  FilledButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    ),
                    child: const Text('Get Started'),
                  ),
                  const SizedBox(height: 60),

                  Text(
                    '© 2026 CLASSHUB (ISIMM EDITION)',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      letterSpacing: 0.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}