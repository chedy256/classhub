import 'package:test/test.dart';
import 'package:sync_engine/sync/models/file_delta.dart';

void main() {
  group('FileDelta', () {
    test('add delta requires downloadUrl', () {
      expect(
        () => FileDelta(
          relativePath: 'assignments/hw1.pdf',
          type: DeltaType.add,
          downloadUrl: null,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('update delta requires downloadUrl', () {
      expect(
        () => FileDelta(
          relativePath: 'assignments/hw1.pdf',
          type: DeltaType.update,
          downloadUrl: null,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('delete delta does not require downloadUrl', () {
      final delta = FileDelta(
        relativePath: 'assignments/hw1.pdf',
        type: DeltaType.delete,
      );

      expect(delta.downloadUrl, isNull);
      expect(delta.type, DeltaType.delete);
    });

    test('add delta stores path and url correctly', () {
      final delta = FileDelta(
        relativePath: 'lecture1.pdf',
        type: DeltaType.add,
        downloadUrl:
            'https://raw.githubusercontent.com/user/repo/main/lecture1.pdf',
      );

      expect(delta.relativePath, 'lecture1.pdf');
      expect(delta.downloadUrl, isNotNull);
    });
  });
}
