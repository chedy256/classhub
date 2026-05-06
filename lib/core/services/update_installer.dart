import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sync_foreground_service.dart';

class UpdateInstaller {
  final SyncForegroundService _nativeService = SyncForegroundService();

  Future<String?> downloadApk(String apkUrl) async {
    File? apkFile;
    try {
      final dir = await getTemporaryDirectory();
      apkFile = File('${dir.path}/classhub_update.apk');

      final expectedSize = await _getRemoteFileSize(apkUrl);
      debugPrint('[UpdateInstaller] Expected size: $expectedSize bytes');

      if (expectedSize != null && apkFile.existsSync()) {
        final localSize = apkFile.lengthSync();
        debugPrint('[UpdateInstaller] Local size: $localSize bytes');
        if (localSize == expectedSize) {
          debugPrint('[UpdateInstaller] APK already exists, skipping download');
          return apkFile.path;
        }
        debugPrint('[UpdateInstaller] Size mismatch, re-downloading');
        await apkFile.delete();
      }

      _nativeService.start('Update', 100);

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(apkUrl));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          debugPrint('[UpdateInstaller] Download failed: ${response.statusCode}');
          _nativeService.stop();
          return null;
        }

        int totalSize = response.contentLength ?? expectedSize ?? 0;
        int received = 0;
        int lastPercent = 0;

        final sink = apkFile.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;

            if (totalSize > 0) {
              final percent = ((received / totalSize) * 100).toInt();
              if (percent != lastPercent && percent <= 100) {
                lastPercent = percent;
                _nativeService.update(
                  percent: percent,
                  currentFile: 'Downloading update...',
                  completed: percent,
                  total: 100,
                );
              }
            }
          }
        } finally {
          await sink.close();
        }

        if (totalSize > 0) {
          final actualSize = apkFile.lengthSync();
          debugPrint('[UpdateInstaller] Downloaded: $actualSize / $totalSize bytes');
          if (actualSize != totalSize) {
            debugPrint('[UpdateInstaller] Size mismatch after download, deleting');
            await apkFile.delete();
            _nativeService.stop();
            return null;
          }
        }

        _nativeService.update(
          percent: 100,
          currentFile: 'Download complete',
          completed: 100,
          total: 100,
        );

        _nativeService.stop();

        debugPrint('[UpdateInstaller] Download complete: ${apkFile.path}');
        return apkFile.path;
      } finally {
        client.close();
      }
    } catch (e, st) {
      debugPrint('[UpdateInstaller] Error: $e\n$st');
      _nativeService.stop();
      if (apkFile?.existsSync() == true) {
        try {
          await apkFile!.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  Future<int?> _getRemoteFileSize(String url) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request('HEAD', Uri.parse(url));
        final response = await client.send(request);
        return response.contentLength;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkInstallPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;

    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  Future<bool> install(String apkPath) async {
    debugPrint('[UpdateInstaller] Installing: $apkPath');

    final hasPermission = await _checkInstallPermission();
    if (!hasPermission) {
      debugPrint('[UpdateInstaller] Install permission denied by user');
      return false;
    }

    final result = await OpenFile.open(apkPath);
    debugPrint('[UpdateInstaller] Install result: ${result.type} - ${result.message}');
    return result.type == ResultType.done;
  }
}
