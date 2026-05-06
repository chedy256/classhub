import 'dart:async';
import 'package:flutter/services.dart';

class SyncForegroundService {
  static const _channel = MethodChannel('com.knisium.classhub/sync_service');
  static final SyncForegroundService _instance = SyncForegroundService._internal();

  factory SyncForegroundService() => _instance;
  SyncForegroundService._internal();

  Future<void> start(String sourceName, int total) async {
    await _channel.invokeMethod('start', {
      'sourceName': sourceName,
      'total': total,
    });
  }

  Future<void> update({
    required int percent,
    required String currentFile,
    required int completed,
    required int total,
  }) async {
    await _channel.invokeMethod('update', {
      'percent': percent,
      'currentFile': currentFile,
      'completed': completed,
      'total': total,
    });
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
