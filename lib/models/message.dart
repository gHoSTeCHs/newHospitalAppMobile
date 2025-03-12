import './message_file.dart';
import './message_status.dart';
import './user.dart';

class Message {
  final int id;
  final dynamic conversationId;
  final int senderId;
  final String messageType;
  final String content;
  final bool isAlert;
  final bool isEmergency;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? sender;
  final List<MessageFile> files;
  final List<MessageStatus> status;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    required this.content,
    required this.isAlert,
    required this.isEmergency,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    required this.files,
    required this.status,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      messageType: json['message_type'],
      content: json['content'],
      isAlert: json['is_alert'] ?? false,
      isEmergency: json['is_emergency'] ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      files:
          json['files'] != null
              ? (json['files'] as List)
                  .map((file) => MessageFile.fromJson(file))
                  .toList()
              : [],
      status:
          json['status'] != null
              ? (json['status'] as List)
                  .map((status) => MessageStatus.fromJson(status))
                  .toList()
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': messageType,
      'content': content,
      'is_alert': isAlert,
      'is_emergency': isEmergency,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sender': sender?.toJson(),
      'files': files.map((file) => file.toJson()).toList(),
      'status': status.map((status) => status.toJson()).toList(),
    };
  }

  // Check if the message is from the current user
  bool isFromCurrentUser(int currentUserId) {
    return senderId == currentUserId;
  }
}
