import 'package:flutter/material.dart';

enum FileCategory {
  photos,
  videos,
  documents,
  audio,
  archives,
  others,
}

class FileCategoryHelper {
  // Centralized definition of extensions per category
  static const Map<FileCategory, Set<String>> _extensionMap = {
    FileCategory.photos: {
      'jpg', 'jpeg', 'png', 'webp', 'heic', 'gif', 'bmp', 'svg', 'ico', 'tiff', 'tif'
    },
    FileCategory.videos: {
      'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', '3gp', 'wmv', 'm4v', 'mpg', 'mpeg'
    },
    FileCategory.documents: {
      // Docs
      'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'rtf', 'csv', 'md', 'epub',
      // Code
      'html', 'htm', 'css', 'js', 'ts', 'jsx', 'tsx', 'json', 'xml', 'yaml', 'yml',
      'c', 'cpp', 'h', 'cs', 'java', 'kt', 'kts', 'dart', 'py', 'rb', 'go', 'rs', 'php', 'sh', 'bat', 'env', 'gradle', 'properties', 'sql'
    },
    FileCategory.audio: {
      'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'wma', 'opus', 'mid', 'midi'
    },
    FileCategory.archives: {
      'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'iso', 'xz'
    }
  };

  static FileCategory getCategoryFromExtension(String? extension) {
    if (extension == null) return FileCategory.others;
    
    final ext = extension.toLowerCase().replaceFirst('.', '');
    
    for (final entry in _extensionMap.entries) {
      if (entry.value.contains(ext)) {
        return entry.key;
      }
    }
    
    return FileCategory.others;
  }
  
  static String getCategoryName(FileCategory category) {
    switch (category) {
      case FileCategory.photos:
        return 'Photos';
      case FileCategory.videos:
        return 'Videos';
      case FileCategory.documents:
        return 'Documents';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.archives:
        return 'Archives';
      case FileCategory.others:
        return 'Others';
    }
  }
  
  static IconData getCategoryIcon(FileCategory category) {
    switch (category) {
      case FileCategory.photos:
        return Icons.photo_library_rounded;
      case FileCategory.videos:
        return Icons.video_library_rounded;
      case FileCategory.documents:
        return Icons.description_rounded;
      case FileCategory.audio:
        return Icons.audio_file_rounded;
      case FileCategory.archives:
        return Icons.folder_zip_rounded;
      case FileCategory.others:
        return Icons.insert_drive_file_rounded;
    }
  }
  
  static Color getCategoryColor(FileCategory category) {
    switch (category) {
      case FileCategory.photos:
        return const Color(0xFF7986CB); // Soft blue
      case FileCategory.videos:
        return const Color(0xFFBA68C8); // Soft purple
      case FileCategory.documents:
        return const Color(0xFF4FC3F7); // Light blue
      case FileCategory.audio:
        return const Color(0xFF81C784); // Soft green
      case FileCategory.archives:
        return const Color(0xFFFFB74D); // Soft orange
      case FileCategory.others:
        return const Color(0xFF90A4AE); // Gray
    }
  }

  static List<String> getExtensionsForCategory(FileCategory category) {
    if (category == FileCategory.others) return []; 
    return _extensionMap[category]?.toList() ?? [];
  }
}
