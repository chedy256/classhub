import 'package:flutter/material.dart';
import 'package:classhub/share/services/deep_link_service.dart';
import 'package:classhub/share/screens/add_screen.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final _linkService = LinkService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _linkService.linkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    final urls = _linkService.extractAddUrls(uri);
    if (urls.isEmpty || !mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddScreen(incomingUrls: urls)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('File Explorer')));
  }
}
