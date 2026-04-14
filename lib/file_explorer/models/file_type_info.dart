import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileTypeInfo {
  final String label;
  final IconData icon;
  const FileTypeInfo(this.label, this.icon);

  static FileTypeInfo classify(String name, {bool isDirectory = false}) {
    if (isDirectory) {
      return const FileTypeInfo('Folder', Icons.folder_outlined);
    }
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.pdf':
        return const FileTypeInfo(
          'PDF Document',
          Icons.picture_as_pdf_outlined,
        );
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
      case '.webm':
        return const FileTypeInfo('Video', Icons.ondemand_video_outlined);
      case '.xls':
      case '.xlsx':
        return const FileTypeInfo('Spreadsheet', Icons.grid_on_outlined);
      case '.csv':
        return const FileTypeInfo('CSV File', Icons.grid_on_outlined);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return const FileTypeInfo('Compressed', Icons.inventory_2_outlined);
      case '.md':
        return const FileTypeInfo('Markdown', Icons.notes_outlined);
      case '.txt':
        return const FileTypeInfo('Text File', Icons.notes_outlined);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.webp':
      case '.svg':
        return const FileTypeInfo('Image', Icons.image_outlined);
      case '.pptx':
      case '.ppt':
        return const FileTypeInfo('Presentation', Icons.slideshow_outlined);
      case '.doc':
      case '.docx':
        return const FileTypeInfo('Document', Icons.description_outlined);
      default:
        return const FileTypeInfo('File', Icons.insert_drive_file_outlined);
    }
  }
}
