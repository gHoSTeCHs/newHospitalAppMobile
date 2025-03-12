class ChatModel {
  final int id;
  final String name;
  final String message;
  final String time;
  final String avatarUrl;
  final int unreadCount;
  final bool isOnline;

  ChatModel({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.avatarUrl,
    required this.unreadCount,
    required this.isOnline,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // Extract participants
    List<dynamic> participants = json['participants'] ?? [];

    // Extract participant name and avatar for individual chats
    String chatName = json['name'] ?? 'Unknown';
    String avatar = '';

    if (json['type'] == 'individual' && participants.isNotEmpty) {
      // Get the first participant (excluding current user)
      final otherParticipant = participants.first;
      chatName = otherParticipant['name'] ?? 'Unknown';
      avatar = otherParticipant['avatar_url'] ?? '';
    }

    return ChatModel(
      id: json['id'],
      name: chatName,
      message: json['last_message']?['content'] ?? 'No messages yet',
      time: json['last_message']?['created_at'] ?? '',
      avatarUrl: avatar,
      unreadCount: json['unread_count'] ?? 0,
      isOnline: false, // API does not return online status yet
    );
  }
}
