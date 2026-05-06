import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:sync_engine/sync_engine.dart';

extension SourceTypeIcon on SourceType? {
  IconData get icon {
    return switch (this) {
      SourceType.github => MdiIcons.github,
      SourceType.drive => MdiIcons.googleDrive,
      SourceType.classroom => Icons.school,
      null => Icons.folder_outlined,
    };
  }

  Widget iconWidget({double size = 24, Color? color}) {
    return Icon(icon, size: size, color: color);
  }
}
