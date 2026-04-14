import 'dart:convert';

class TrashItem {
  final String originalPath;
  final String trashPath;
  final bool isDirectory;
  final DateTime deletedAt;

  const TrashItem({
    required this.originalPath,
    required this.trashPath,
    required this.isDirectory,
    required this.deletedAt,
  });

  /// Days remaining before permanent deletion (30-day policy)
  int get daysRemaining {
    final expiry = deletedAt.add(const Duration(days: 30));
    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  bool get isExpired => daysRemaining <= 0;

  Map<String, dynamic> toJson() => {
    'originalPath': originalPath,
    'trashPath': trashPath,
    'isDirectory': isDirectory,
    'deletedAt': deletedAt.toIso8601String(),
  };

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
    originalPath: json['originalPath'] as String,
    trashPath: json['trashPath'] as String,
    isDirectory: json['isDirectory'] as bool,
    deletedAt: DateTime.parse(json['deletedAt'] as String),
  );

  static String encodeList(List<TrashItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<TrashItem> decodeList(String source) {
    final list = jsonDecode(source) as List;
    return list
        .map((e) => TrashItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
