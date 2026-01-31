import 'package:flutter/material.dart';
import '../config/theme.dart';

class FileIcons {
  /// Get icon for file type based on extension
  static IconData getIconForFileType(String? extension, bool isFolder) {
    if (isFolder) {
      return Icons.folder_rounded;
    }

    if (extension == null) {
      return Icons.description_rounded;
    }

    switch (extension.toLowerCase()) {
      // Documents
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'txt':
        return Icons.article_rounded;

      // Spreadsheets
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;

      // Presentations
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;

      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'webp':
        return Icons.image_rounded;

      // Videos
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'webm':
        return Icons.video_file_rounded;

      // Audio
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'm4a':
        return Icons.audio_file_rounded;

      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;

      // Code
      case 'js':
      case 'jsx':
      case 'ts':
      case 'tsx':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'dart':
      case 'go':
        return Icons.code_rounded;

      default:
        return Icons.description_rounded;
    }
  }

  /// Get color for file type
  static Color getColorForFileType(String? extension, bool isFolder) {
    if (isFolder) {
      return AppTheme.folderColor;
    }

    if (extension == null) {
      return AppTheme.defaultFileColor;
    }

    switch (extension.toLowerCase()) {
      case 'pdf':
        return AppTheme.pdfColor;
      case 'txt':
      case 'doc':
      case 'docx':
        return AppTheme.textFileColor;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'webp':
        return AppTheme.imageColor;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return AppTheme.sheetColor;
      case 'ppt':
      case 'pptx':
        return AppTheme.presentationColor;
      default:
        return AppTheme.defaultFileColor;
    }
  }

  /// Get background color with opacity for icon container
  static Color getBackgroundColor(String? extension, bool isFolder) {
    final color = getColorForFileType(extension, isFolder);
    return color.withOpacity(0.15);
  }
}
