package com.knisium.classhub

import io.flutter.embedding.engine.plugins.FlutterPlugin

class PdfViewerPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "native_pdf_viewer",
            PdfViewerFactory(binding.binaryMessenger)  // ✅ pass messenger
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}