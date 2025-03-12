import 'package:flutter/material.dart';
// import 'package:flutterapplication/screens/chat/c_d_s.dart';
import 'package:flutterapplication/screens/chat/chat_details_screen.dart';
import '../../models/chat.dart';
import '../../services/chat_service.dart'; // ChatService for API calls
// import 'chat_details_screen.dart';
import '../../widgets/chat_filter_chip.dart';
import '../../widgets/chat_tile.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _selectedFilter = "All chats";
  final List<String> _filters = ["All chats", "Personal", "Work", "Groups"];
  late Future<List<ChatModel>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = fetchChats(); // Fetch chats when screen loads
  }

  Future<List<ChatModel>> fetchChats() async {
    try {
      final chatService = ChatService();
      final response = await chatService.getConversations();

      List<dynamic> conversationList = response.data['conversations'] ?? [];
      return conversationList
          .map<ChatModel>((chat) => ChatModel.fromJson(chat))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _handleFilterChange(String filter) {
    setState(() {
      _selectedFilter = filter;
      _chatsFuture = fetchChats(); // Re-fetch chats on filter change
    });
  }

  void _navigateToChatDetail(BuildContext context, ChatModel chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatDScreen(
              chatId: chat.id,
              name: chat.name,
              avatarUrl: chat.avatarUrl,
              isOnline: chat.isOnline,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = filter == _selectedFilter;

              return ChatFilterChip(
                label: filter,
                isSelected: isSelected,
                onSelected: (_) => _handleFilterChange(filter),
              );
            },
          ),
        ),

        // Chat list
        Expanded(
          child: FutureBuilder<List<ChatModel>>(
            future: _chatsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Text('Failed to load chats'));
              }

              final chats = snapshot.data!;
              if (chats.isEmpty) {
                return const Center(child: Text('No chats yet'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];

                  return ChatTile(
                    name: chat.name,
                    message: chat.message,
                    time: chat.time,
                    unreadCount: chat.unreadCount,
                    isOnline: chat.isOnline,
                    onTap: () => _navigateToChatDetail(context, chat),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
