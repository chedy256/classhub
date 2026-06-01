import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class MarkdownPreviewScreen extends StatefulWidget {
  final String filePath;

  const MarkdownPreviewScreen({super.key, required this.filePath});

  @override
  State<MarkdownPreviewScreen> createState() => _MarkdownPreviewScreenState();
}

class _MarkdownPreviewScreenState extends State<MarkdownPreviewScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLink(String text, String? href, String title) async {
    if (href == null) return;

    final fileDir = p.dirname(widget.filePath);

    if (href.startsWith('http://') || href.startsWith('https://')) {
      final url = Uri.parse(href);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link')));
        }
      }
      return;
    }

    if (href.startsWith('#')) {
      return;
    }

    final targetPath = p.normalize(p.join(fileDir, href));
    final file = File(targetPath);

    if (file.existsSync()) {
      if (targetPath.toLowerCase().endsWith('.md')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarkdownPreviewScreen(filePath: targetPath),
          ),
        );
      } else {
        OpenFile.open(targetPath);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File not found: $href')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.filePath);

    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: FutureBuilder<String>(
        future: File(widget.filePath).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading markdown: ${snapshot.error}'),
            );
          }
          final content = snapshot.data ?? '';
          return Markdown(
            controller: _scrollController,
            data: content,
            onTapLink: _handleLink,
            imageBuilder: (uri, title, alt) {
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
