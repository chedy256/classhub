import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sync_engine/sync_engine.dart';

extension SourceTypeIcon on SourceType? {
  FaIconData get icon {
    return (switch (this) {
      SourceType.github => FontAwesomeIcons.github,
      SourceType.drive => FontAwesomeIcons.googleDrive,
      SourceType.classroom => FontAwesomeIcons.graduationCap,
      null => FontAwesomeIcons.folder,
    });
  }

  Widget iconWidget({double size = 24, Color? color}) {
    return Center(
      child: FaIcon(icon, size: size, color: color),
    );
  }
}
