import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sync_foreground_service.dart';

class UpdateInstaller {
  final SyncForegroundService _nativeService = SyncForegroundService();
  bool _isDownloading = false;

  Future<String?> downloadApk(
    String apkUrl, {
    String? checksumUrl,
    void Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) {
      debugPrint('[UpdateInstaller] Already downloading');
      return null;
    }
    _isDownloading = true;

    File? apkFile;
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/classhub_update.apk';
      apkFile = File(filePath);

      if (apkFile.existsSync()) {
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

        final totalSize = response.contentLength ?? 0;
        int received = 0;
        int lastPercent = 0;

        final sink = apkFile.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;

            if (totalSize > 0) {
              final progress = received / totalSize;
              final percent = (progress * 100).toInt();
              onProgress?.call(progress);

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

        if (checksumUrl != null) {
          final valid = await _verifyChecksum(apkFile, checksumUrl);
          if (!valid) {
            debugPrint('[UpdateInstaller] Checksum mismatch, deleting');
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
    } finally {
      _isDownloading = false;
    }
  }

  Future<bool> _verifyChecksum(File file, String checksumUrl) async {
    try {
      final response = await http.get(Uri.parse(checksumUrl)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        debugPrint('[UpdateInstaller] Failed to fetch checksum: ${response.statusCode}');
        return true;
      }

      final expected = response.body.trim().split(RegExp(r'\s+')).first;
      if (expected.isEmpty) {
        debugPrint('[UpdateInstaller] Empty checksum from server');
        return true;
      }

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      debugPrint('[UpdateInstaller] Expected: $expected');
      debugPrint('[UpdateInstaller] Actual:   $hash');

      return hash == expected;
    } catch (e) {
      debugPrint('[UpdateInstaller] Checksum verification error: $e');
      return true;
    }
  }

  Future<bool> _checkInstallPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;

    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  static const _installChannel = MethodChannel('com.knisium.classhub/apk_install');

  Future<bool> install(String apkPath) async {
    debugPrint('[UpdateInstaller] Installing: $apkPath');

    final hasPermission = await _checkInstallPermission();
    if (!hasPermission) {
      debugPrint('[UpdateInstaller] Install permission denied by user');
      return false;
    }

    try {
      await _installChannel.invokeMethod('installApk', {'path': apkPath});
      debugPrint('[UpdateInstaller] Install intent sent');
      return true;
    } catch (e) {
      debugPrint('[UpdateInstaller] Install failed: $e');
      return false;
    }
  }
}
