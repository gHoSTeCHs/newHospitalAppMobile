import 'package:intl/intl.dart';

class DateFormatter {
  static String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }

  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Format time
    final timeFormat = DateFormat('h:mm a');
    final time = timeFormat.format(dateTime);

    // For messages from today, just show time
    if (messageDate == today) {
      return time;
    }
    // For messages from yesterday, show "Yesterday" and time
    else if (messageDate == yesterday) {
      return 'Yesterday, $time';
    }
    // For messages from within the last week, show day name and time
    else if (now.difference(messageDate).inDays < 7) {
      final dayFormat = DateFormat('EEEE');
      return '${dayFormat.format(dateTime)}, $time';
    }
    // For older messages, show full date
    else {
      final dateFormat = DateFormat('MMM d');
      return '${dateFormat.format(dateTime)}, $time';
    }
  }
}
