import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  final _documentationKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDocumentation() {
    final context = _documentationKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090C14), // Deep dark background
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: 15,
            left: MediaQuery.of(context).size.width / 2 - 200,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2C4477).withValues(alpha: 0.9),
                    const Color(0xFF090C14).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ClassHub',
                          style: TextStyle(
                            color: Color(0xFF80A3FF),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),

                      // Hero Section
                      const Text(
                        'Organize Your\nCourse\nMaterials',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 30),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'GitHub meets Google Classroom - \nLocally. A professional workspace\ndesigned for students to manage\nacademic repositories.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF8C95A6),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 150),

                      // Call to Action Buttons
                      Center(
                        child: Column(
                          children: [
                            _PrimaryGlowButton(
                              text: 'Get Started',
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const OnboardingScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _scrollToDocumentation,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF141A29),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'View Documentation',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 170),

                      // === Documentation Section ===
                      SizedBox(key: _documentationKey, height: 0),

                      // Large Feature Card 1
                      _FeatureCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Local Repository\nSync',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Manage files with Git-like efficiency',
                                          style: TextStyle(
                                            color: Color(0xFF8C95A6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.account_tree_outlined,
                                    color: Color(0xFF80A3FF),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),

                            // Mock Window Illustration
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ).copyWith(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF030303),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Window Controls
                                  Row(
                                    children: [
                                      _buildDot(const Color(0xFFFF5F56)),
                                      const SizedBox(width: 6),
                                      _buildDot(const Color(0xFF272932)),
                                      const SizedBox(width: 6),
                                      _buildDot(const Color(0xFF272932)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Mock Text Lines
                                  _buildMockLine(width: double.infinity),
                                  const SizedBox(height: 10),
                                  _buildMockLine(width: 150),
                                  const SizedBox(height: 10),
                                  _buildMockLine(width: 200),
                                  const SizedBox(height: 20),

                                  // Mock File Blocks
                                  Row(
                                    children: [
                                      _buildMockFileBox(
                                        Icons.description_outlined,
                                        const Color(0xFF80A3FF),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildMockFileBox(
                                        Icons.folder_outlined,
                                        const Color(0xFFD979FF),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildMockFileBox(
                                        Icons.inventory_2_outlined,
                                        const Color(0xFF8C95A6),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Feature Card 2
                      const _SmallFeatureCard(
                        icon:
                            Icons.speed_outlined, // Closer to cloud-search look
                        title: 'Instant Indexing',
                        description:
                            'Never lose a PDF or Slide again. Search across all your local semesters in milliseconds.',
                      ),
                      const SizedBox(height: 16),

                      // Feature Card 3
                      const _SmallFeatureCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Offline First',
                        description:
                            'Works entirely on your machine. No internet required for browsing your knowledge base.',
                        iconColor: Color(0xFFD979FF),
                        iconBgColor: Color(0xFF331D42),
                      ),
                      const SizedBox(height: 16),

                      // Feature Card 4
                      const _SmallFeatureCard(
                        icon: Icons.lock_outline_rounded,
                        title: 'Privacy Guaranteed',
                        description:
                            'Your data stays where it belongs - on your device. No cloud sync, no tracking, total control.',
                      ),
                      const SizedBox(height: 60),

                      // Bottom CTA
                      Center(
                        child: _PrimaryGlowButton(
                          text: 'Get Started',
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const OnboardingScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Footer
                      const Text(
                        '© 2026 CLASSHUB (ISIMM EDITION) - CRAFTED FOR\nACADEMIC EXCELLENCE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF4B5263),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  // Helper widgets for the mock window illustration
  Widget _buildDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildMockLine({required double width}) {
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildMockFileBox(IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF13151A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

// Reusable Components

class _PrimaryGlowButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryGlowButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80A3FF).withValues(alpha: 0.35),
            blurRadius: 25,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF80A3FF), // Light brand blue
          foregroundColor: const Color(0xFF090C14), // Dark text
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _FeatureCard({
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151822), // Card dark color
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SmallFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color iconBgColor;

  const _SmallFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = const Color(0xFF80A3FF),
    this.iconBgColor = const Color(0xFF1A2136),
  });

  @override
  Widget build(BuildContext context) {
    return _FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF8C95A6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}