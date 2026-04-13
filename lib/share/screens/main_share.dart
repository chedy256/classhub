import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:classhub/share/services/deep_link_service.dart';
import 'package:classhub/share/screens/add_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _linkService = LinkService();
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    setState(() {
      _initialScreen = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      // ── Cold start (app était fermée) ──────────────────────────────────
      final initialUri = await _linkService.getInitialLink();

      if (kDebugMode) {
        debugPrint('========== DEEP LINK DEBUG ==========');
        debugPrint('Lien reçu: $initialUri');
      }

      if (initialUri != null) {
        final urls = _linkService.extractAddUrls(initialUri);

        if (kDebugMode) debugPrint('URLs extraites: $urls');

        if (urls.isNotEmpty && mounted) {
          setState(() {
            _initialScreen = AddScreen(incomingUrls: urls);
          });
          _listenToLinkStream(); // continuer à écouter
          return;
        }
      }

      // ── Aucun lien → écran normal ──────────────────────────────────────
      if (kDebugMode) debugPrint('Aucun lien, écran normal');
      if (mounted) {
        setState(() {
          _initialScreen = const _HomeScreen();
        });
      }

      _listenToLinkStream();
    } catch (e) {
      if (kDebugMode) debugPrint('ERREUR deep link: $e');
      if (mounted) {
        setState(() {
          _initialScreen = const _HomeScreen();
        });
      }
    }
  }

  // ── Stream (app déjà ouverte) ────────────────────────────────────────────
  void _listenToLinkStream() {
    _linkService.linkStream.listen((uri) {
      if (kDebugMode) {
        debugPrint('========== NOUVEAU LIEN ==========');
        debugPrint('URI: $uri');
      }

      final urls = _linkService.extractAddUrls(uri);

      if (kDebugMode) debugPrint('URLs: $urls');

      if (urls.isNotEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddScreen(incomingUrls: urls)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialScreen == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Classhub',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: _initialScreen,
    );
  }
}

// ── Écran d'accueil par défaut ───────────────────────────────────────────────
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return AddScreen(incomingUrls: const []); //
  }
}
