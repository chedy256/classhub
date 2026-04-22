// lib/sync/models/file_delta.dart

enum DeltaType { add, update, delete }

class FileDelta {
  final String relativePath; // e.g. "compilation/chapter1.pdf"
  final String? downloadUrl; // null for deletes
  final DeltaType type;

  const FileDelta({
    required this.relativePath,
    required this.type,
    this.downloadUrl,
  }) : assert(
         type == DeltaType.delete || downloadUrl != null,
         'downloadUrl is required for add/update deltas',
       );
}
