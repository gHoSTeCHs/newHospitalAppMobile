import 'package:flutter/material.dart';
import 'package:hospital_app/models/message.dart';

class Styling {
  static Color getMessageBackgroundColor(Message message, bool isMe) {
    if (message.isEmergency) {
      return isMe ? Colors.red.shade400 : Colors.red.shade50;
    } else if (message.isAlert) {
      return isMe ? Colors.amber.shade500 : Colors.amber.shade50;
    } else {
      return isMe ? Colors.blue.shade600 : Colors.grey.shade100;
    }
  }

  static Border? getMessageBorder(Message message) {
    if (message.isEmergency) {
      return Border.all(color: Colors.red.shade300);
    } else if (message.isAlert) {
      return Border.all(color: Colors.amber.shade300);
    } else {
      return null;
    }
  }

  static getMessageShadowColor(Message message, bool isMe) {
    if (message.isEmergency) {
      return Colors.red.withOpacity(0.3);
    } else if (message.isAlert) {
      return Colors.amber.withOpacity(0.3);
    } else {
      return Colors.black.withOpacity(0.05);
    }
  }

  static getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    } else if (mimeType.startsWith('video/')) {
      return Icons.videocam;
    } else if (mimeType.startsWith('audio/')) {
      return Icons.audiotrack;
    } else if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('msword')) {
      return Icons.description;
    } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return Icons.table_chart;
    } else {
      return Icons.insert_drive_file;
    }
  }

  static getFileTypeLabel(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return 'Image';
    } else if (mimeType.startsWith('video/')) {
      return 'Video';
    } else if (mimeType.startsWith('audio/')) {
      return 'Audio';
    } else if (mimeType == 'application/pdf') {
      return 'PDF';
    } else if (mimeType.contains('word') || mimeType.contains('msword')) {
      return 'Document';
    } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return 'Spreadsheet';
    } else {
      return 'File';
    }
  }
}
