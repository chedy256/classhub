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
  List<String> _incomingUrls = [];
  bool _hasLink = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    if (kDebugMode) {
      debugPrint('========== DEEP LINK DEBUG ==========');
    }

    final initialUri = await _linkService.getInitialLink();

    if (kDebugMode) debugPrint('Lien recu: $initialUri');

    if (initialUri != null) {
      final urls = _linkService.extractAddUrls(initialUri);
      if (kDebugMode) debugPrint('URLs extraites: $urls');
      if (urls.isNotEmpty && mounted) {
        setState(() {
          _incomingUrls = urls;
          _hasLink = true;
        });
      }
    }

    _listenToLinkStream();
  }

  void _listenToLinkStream() {
    _linkService.linkStream.listen((uri) {
      if (kDebugMode) debugPrint('========== NOUVEAU LIEN ==========');

      final urls = _linkService.extractAddUrls(uri);
      if (kDebugMode) debugPrint('URLs: $urls');

      if (urls.isNotEmpty && mounted) {
        setState(() {
          _incomingUrls = urls;
          _hasLink = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classhub',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Classhub')),
        body: Center(
          child: _hasLink
              ? ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          AddSourceDialog(incomingUrls: _incomingUrls),
                    );
                  },
                  child: const Text('Ouvrir AddSourceDialog'),
                )
              : const Text('Aucune URL recue'),
        ),
      ),
    );
  }
}
