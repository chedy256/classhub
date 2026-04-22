import 'package:test/test.dart';
import 'package:sync_engine/sync/models/sync_result.dart';

void main() {
  group('SyncResult', () {
    test('totalChanges sums all three counters', () {
      final result = SyncResult(
        success: true,
        syncedAt: DateTime.now(),
        filesAdded: 3,
        filesUpdated: 2,
        filesDeleted: 1,
      );

      expect(result.totalChanges, 6);
    });

    test('totalChanges is zero when nothing changed', () {
      final result = SyncResult(success: true, syncedAt: DateTime.now());

      expect(result.totalChanges, 0);
    });

    test('failure factory sets success false and error message', () {
      final result = SyncResult.failure('network timeout');

      expect(result.success, isFalse);
      expect(result.error, 'network timeout');
      expect(result.filesAdded, 0);
      expect(result.filesUpdated, 0);
      expect(result.filesDeleted, 0);
    });

    test('failure factory sets syncedAt to now', () {
      final before = DateTime.now().toUtc();
      final result = SyncResult.failure('error');
      final after = DateTime.now().toUtc();

      expect(
        result.syncedAt.isAfter(before) ||
            result.syncedAt.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        result.syncedAt.isBefore(after) ||
            result.syncedAt.isAtSameMomentAs(after),
        isTrue,
      );
    });
  });
}
