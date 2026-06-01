import 'package:flutter/material.dart';
import 'pdf_viewer_widget.dart';
import 'pdf_controller.dart';
import 'dart:async';

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final _pdfController = PdfController();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    // Periodically sync the current page while viewing
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pdfController.syncCurrentPage();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ListenableBuilder(
            listenable: _pdfController,
            builder: (context, _) {
              if (_pdfController.totalPages == 0) return const SizedBox.shrink();
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '${_pdfController.currentPage + 1} / ${_pdfController.totalPages}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: NativePdfViewer(
        filePath: widget.filePath,
        initialPage: 0,
        onViewCreated: (viewId) {
          _pdfController.attachChannel(viewId);
        },
      ),
    );
  }
}