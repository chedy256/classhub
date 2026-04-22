import 'dart:io';
import 'package:sync_engine/sync/sources/github/parser.dart';
import 'package:sync_engine/sync_engine.dart';

void main() async {
  // Initialize
  final appFolder = Directory('/tmp/example_app_folder/');
  final syncEngine = SyncEngine(appFolder: appFolder);
  final url = 'https://github.com/titanknis/nixos';
  //
  // // Add a GitHub source
  // final SyncResult githubResult = await syncEngine.addSource(url);
  // print(
  //   'GitHub Sync: ${githubResult.success ? "Success" : "Failed: ${githubResult.error}"}',
  // );

  final parser = GithubParser();

  // Sync the source again (incremental)
  final sourceFolder = Directory(
    '${appFolder.path}/${parser.getSourceFolderName(url)}',
  );
  final syncResult = await syncEngine.syncSource(sourceFolder);
  print('Re-sync: ${syncResult.totalChanges} changes');
}
