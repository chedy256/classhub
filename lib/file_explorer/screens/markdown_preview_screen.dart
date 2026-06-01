import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final fileDir = p.dirname(filePath);

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
            imageDirectory: fileDir,
            builders: {
              'html': HtmlElementBuilder(fileDir: fileDir),
            },
            imageBuilder: (uri, title, alt) {
              return _buildImage(uri.toString(), fileDir, alt);
            },
          );
        },
      ),
    );
  }

  static Widget _buildImage(String uriPath, String fileDir, String? alt) {
    if (uriPath.startsWith('http')) {
      if (uriPath.toLowerCase().contains('.svg') ||
          uriPath.toLowerCase().contains('img.shields.io') ||
          uriPath.toLowerCase().contains('contrib.rocks')) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SvgPicture.network(
            uriPath,
            placeholderBuilder: (context) => const SizedBox(
              width: 24,
              height: 24,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorBuilder: (context, error, stackTrace) => _imageError(alt),
          ),
        );
      }
      return Image.network(
        uriPath,
        errorBuilder: (context, error, stackTrace) => _imageError(alt),
      );
    }

    // Handle local files
    File imageFile;
    if (p.isAbsolute(uriPath)) {
      imageFile = File(uriPath);
    } else {
      imageFile = File(p.join(fileDir, uriPath));
    }

    if (imageFile.existsSync()) {
      if (imageFile.path.toLowerCase().endsWith('.svg')) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SvgPicture.file(imageFile),
        );
      }
      return Image.file(
        imageFile,
        errorBuilder: (context, error, stackTrace) => _imageError(alt),
      );
    }

    return _imageError(alt);
  }

  static Widget _imageError(String? alt) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey),
          if (alt != null) ...[
            const SizedBox(height: 4),
            Text(
              alt,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class HtmlElementBuilder extends MarkdownElementBuilder {
  final String fileDir;

  HtmlElementBuilder({required this.fileDir});

  @override
  Widget? visitElementAfter(element, preferredStyle) {
    final htmlContent = element.textContent;

    return HtmlWidget(
      htmlContent,
      onTapUrl: (url) async {
        return true;
      },
      factoryBuilder: () => LocalAssetHtmlFactory(fileDir),
    );
  }
}

class LocalAssetHtmlFactory extends WidgetFactory {
  final String fileDir;

  LocalAssetHtmlFactory(this.fileDir);

  @override
  Widget? buildImageWidget(BuildTree meta, ImageSource src) {
    final url = src.url;

    if (url.startsWith('http')) {
      return super.buildImageWidget(meta, src);
    }

    final localPath = p.isAbsolute(url) ? url : p.join(fileDir, url);
    final file = File(localPath);

    if (file.existsSync()) {
      if (file.path.toLowerCase().endsWith('.svg')) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SvgPicture.file(file),
        );
      }
      return Image.file(file);
    }

    return super.buildImageWidget(meta, src);
  }
}
