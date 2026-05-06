import 'dart:io';
import 'package:sync_engine/sync_engine.dart';

void main() async {
  // Initialize
  final appFolder = Directory('/tmp/classhub/');
  final syncEngine = SyncEngine(appFolder: appFolder, verbose: true);
  final url = 'https://github.com/titanknis/nixos';
  late SyncResult syncResult;

  // Add a GitHub source
  // syncResult = await syncEngine.addSource(url);
  // print(
  //   'GitHub Sync: ${syncResult.success ? "Success" : "Failed: ${syncResult.error}"}',
  // );
  // print('Sync: ${syncResult.totalChanges} changes');

  // Sync the source again (incremental)
  final sourceFolder = Directory('${appFolder.path}/nixos');
  syncResult = await syncEngine.syncSource(
    sourceFolder,
    // forceFullSync: true,
  );
  print('Re-sync: ${syncResult.totalChanges} changes');
}
