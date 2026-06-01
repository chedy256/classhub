import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path/path.dart' as p;

class MarkdownPreviewScreen extends StatelessWidget {
  final String filePath;

  const MarkdownPreviewScreen({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<String>(
        future: File(filePath).readAsString(),
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
            data: content,
          );
        },
      ),
    );
  }
}
