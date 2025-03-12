import 'message.dart';
import 'user.dart';

class Conversation {
  final int id;
  final String? name;
  final String type;
  final int hospitalId;
  final int createdBy;
  final List<User> participants;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    this.name,
    required this.type,
    required this.hospitalId,
    required this.createdBy,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      hospitalId: json['hospital_id'],
      createdBy: json['created_by'],
      participants:
          (json['participants'] as List<dynamic>)
              .map((participant) => User.fromJson(participant))
              .toList(),
      lastMessage:
          json['last_message'] != null
              ? Message.fromJson(json['last_message'])
              : null,
      unreadCount: json['unread_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'hospital_id': hospitalId,
      'created_by': createdBy,
      'participants': participants.map((p) => p.toJson()).toList(),
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper method to get the name for display
  String getDisplayName() {
    if (type == 'group') {
      return name ?? 'Group Chat';
    } else {
      // For individual chat, get the other participant's name
      return participants.isNotEmpty ? participants[0].name : 'Chat';
    }
  }

  // Helper method to get profile picture for display
  String? getDisplayImage() {
    if (type == 'group') {
      return null; // Group placeholder image can be handled in UI
    } else {
      // For individual chat, get the other participant's profile
      return participants.isNotEmpty ? participants[0].profilePicture : null;
    }
  }
}
