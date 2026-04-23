import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'landing_page2.dart';

class LandingPage1 extends StatelessWidget {
  const LandingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              const Spacer(),
              Text(
                'Organize Your\nCourse\nMaterials',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'GitHub meets Google Classroom - '
                'Locally. A professional workspace\ndesigned for students.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingPage2()),
                ),
                child: const Text('Next'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                ),
                child: const Text('Skip'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}