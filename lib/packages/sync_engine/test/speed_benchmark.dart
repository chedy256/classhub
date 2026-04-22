import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sync_engine/sync_engine.dart';

void main() async {
  // Repositories to test
  final repos = [
    'https://github.com/octocat/Hello-World',
    'https://github.com/titanknis/my-coach',
    'https://github.com/titanknis/nixos',
    // 'https://github.com/titanknis/ISIMM-L2-Info-Cours/tree/main/Semestre2',
  ];

  // Create temporary directories
  final tempDir = await Directory.systemTemp.createTemp('sync_benchmark_');
  final syncEngineDir = Directory(path.join(tempDir.path, 'sync_engine'));
  final gitCloneDir = Directory(path.join(tempDir.path, 'git_clone'));

  await syncEngineDir.create();
  await gitCloneDir.create();

  // Initialize sync engine
  final syncEngine = SyncEngine(appFolder: syncEngineDir);

  print('Starting benchmark...\n');
  print(
    'Repository | SyncEngine (ms) | git clone (ms) | Speedup | Files (SE) | Files (git)',
  );
  print(
    '-----------|------------------|----------------|---------|-------------|-------------',
  );

  for (final repoUrl in repos) {
    final repoName = path
        .basename(repoUrl)
        .replaceAll('.git', '')
        .replaceAll(RegExp(r'/.*'), ''); // Remove path after repo name

    print('Benchmarking: $repoUrl');

    // Benchmark SyncEngine
    final syncEngineStopwatch = Stopwatch()..start();
    final syncResult = await syncEngine.addSource(repoUrl);
    syncEngineStopwatch.stop();

    final syncEngineTime = syncEngineStopwatch.elapsedMilliseconds;
    final syncEngineSuccess = syncResult.success;
    final syncEngineFiles = syncResult.totalChanges;

    // Benchmark git clone
    final gitCloneStopwatch = Stopwatch()..start();
    final gitCloneSuccess = await _gitClone(
      repoUrl,
      path.join(gitCloneDir.path, repoName),
    );
    gitCloneStopwatch.stop();

    final gitCloneTime = gitCloneStopwatch.elapsedMilliseconds;
    final gitCloneFiles = gitCloneSuccess
        ? _countFiles(path.join(gitCloneDir.path, repoName))
        : 0;

    // Calculate speedup
    final speedup = gitCloneTime > 0 ? gitCloneTime / syncEngineTime : 0;

    // Print results in table format
    print(
      '${repoName.padRight(11)} | '
      '${syncEngineTime.toString().padLeft(16)} | '
      '${gitCloneTime.toString().padLeft(14)} | '
      '${speedup.toStringAsFixed(2).padLeft(7)}x | '
      '${syncEngineFiles.toString().padLeft(11)} | '
      '${gitCloneFiles.toString().padLeft(11)}',
    );
  }

  // Cleanup
  await tempDir.delete(recursive: true);
  print('\nBenchmark completed. Temporary directory cleaned up.');
}

Future<bool> _gitClone(String repoUrl, String targetDir) async {
  try {
    // Handle URLs with /tree/ by converting to standard git clone URL
    final cleanUrl = repoUrl.replaceAll(RegExp(r'/tree/.*$'), '');
    final result = await Process.run('git', ['clone', cleanUrl, targetDir]);
    return result.exitCode == 0;
  } catch (e) {
    print('Git clone error: $e');
    return false;
  }
}

int _countFiles(String directory) {
  try {
    return Directory(
      directory,
    ).listSync(recursive: true).where((entity) => entity is File).length;
  } catch (e) {
    return 0;
  }
}
