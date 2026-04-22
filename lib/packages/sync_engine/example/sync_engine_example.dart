import 'dart:io';
import 'package:sync_engine/sync_engine.dart';

void main() async {
  // Initialize
  final appFolder = Directory('/tmp/classhub/');
  final syncEngine = SyncEngine(appFolder: appFolder);
  final url = 'https://github.com/da7da7ha/da7da7ha';

  // Add a GitHub source
  // SyncResult syncResult = await syncEngine.addSource(url);
  // print(
  //   'GitHub Sync: ${syncResult.success ? "Success" : "Failed: ${syncResult.error}"}',
  // );

  // Sync the source again (incremental)
  final sourceFolder = Directory('${appFolder.path}/da7da7ha');
  var syncResult = await syncEngine.syncSource(
    sourceFolder,
    // forceFullSync: true,
  );
  print('Re-sync: ${syncResult.totalChanges} changes');
}
