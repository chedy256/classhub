import 'package:flutter/material.dart';
import 'package:sync_engine/sync_engine.dart';

extension SourceTypeIcon on SourceType? {
  IconData get icon {
    return switch (this) {
      SourceType.github => Icons.code,
      SourceType.drive => Icons.cloud,
      SourceType.classroom => Icons.school,
      null => Icons.folder_outlined,
    };
  }
}
