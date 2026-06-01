import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class NativePdfViewer extends StatefulWidget {
  final String filePath;
  final int initialPage;
  final void Function(int viewId)? onViewCreated;

  const NativePdfViewer({
    super.key,
    required this.filePath,
    this.initialPage = 0,
    this.onViewCreated,
  });

  @override
  State<NativePdfViewer> createState() => _NativePdfViewerState();
}

class _NativePdfViewerState extends State<NativePdfViewer> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(NativePdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _channel?.invokeMethod('setDarkMode', {'isDark': isDark});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creationParams = <String, dynamic>{
      'filePath': widget.filePath,
      'initialPage': widget.initialPage,
      'isDark': isDark,
    };

    if (Platform.isAndroid) {
      return PlatformViewLink(
        viewType: 'native_pdf_viewer',
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: 'native_pdf_viewer',
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
            ..addOnPlatformViewCreatedListener((id) {
              params.onPlatformViewCreated(id);
              setState(() {
                _channel = MethodChannel('pdf_viewer/control/$id');
              });
              widget.onViewCreated?.call(id);
            })
            ..create();
        },
      );
    }

    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'native_pdf_viewer',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        onPlatformViewCreated: (id) {
          setState(() {
            _channel = MethodChannel('pdf_viewer/control/$id');
          });
          widget.onViewCreated?.call(id);
        },
      );
    }

    return const Center(child: Text('PDF viewer not supported on this platform'));
  }
}
