import 'package:intl/intl.dart';

class Formatters {
  /// Format file size from bytes to human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(1)} GB';
    }
  }

  /// Format date to human-readable format
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date); // Jan 28
    } else {
      return DateFormat('MMM d, y').format(date); // Jan 28, 2025
    }
  }

  /// Format item count for folders
  static String formatItemCount(int count) {
    if (count == 1) {
      return '1 item';
    } else {
      return '$count items';
    }
  }
}
