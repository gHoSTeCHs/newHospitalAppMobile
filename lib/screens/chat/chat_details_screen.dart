import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:hospital_app/services/auth_service.dart';
import 'package:hospital_app/services/message_service.dart';
import 'package:hospital_app/utils/boxstyling.dart';
import 'dart:async';
import '../../models/message.dart';
import '../../utils/formatters.dart';
import '../../config/app_config.dart';

class ChatDScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String avatarUrl;
  final bool isOnline;

  const ChatDScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
  });

  @override
  State<ChatDScreen> createState() => _ChatDScreenState();
}

class _ChatDScreenState extends State<ChatDScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessageService _messageService = MessageService();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _showEmojiPicker = false;
  final int _limit = AppConfig.defaultPageSize;
  final int _offset = 0;
  bool _hasMoreMessages = true;
  Timer? _refreshTimer;
  int? _currentUserId;

  List<PlatformFile> _selectedFiles = [];

  bool _isAlert = false;
  bool _isEmergency = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _fetchMessages();

    _scrollController.addListener(_scrollListener);

    if (AppConfig.enablePushNotifications) {
      _refreshTimer = Timer.periodic(
        Duration(milliseconds: AppConfig.messageRefreshInterval),
        (_) => _refreshMessages(),
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
      _showErrorSnackbar('Failed to select files');
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = await AuthService().getCurrentUser();
    _currentUserId = user!.id;
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMoreMessages) {}
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _messageService.gM(
        widget.chatId,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _messages = messages;
        _isLoading = false;
        _hasMoreMessages = messages.length == _limit;
      });
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackbar('Failed to load messages');
    }
  }

  Future<void> _refreshMessages() async {
    if (_messages.isEmpty) return;

    try {
      final latestMessages = await _messageService.gM(
        widget.chatId,
        limit: 10,
        offset: 0,
      );
      final newMessages =
          latestMessages
              .where((msg) => !_messages.any((m) => m.id == msg.id))
              .toList();

      if (newMessages.isNotEmpty) {
        setState(() {
          _messages = [...newMessages, ..._messages];
        });
      }
    } catch (e) {
      debugPrint('Error refreshing messages: $e');
    }
  }

  void _toggleAlert() {
    setState(() {
      _isAlert = !_isAlert;
    });
  }

  void _toggleEmergency() {
    setState(() {
      _isEmergency = !_isEmergency;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedFiles.isEmpty) {
      return;
    }

    // if (_selectedFiles.isNotEmpty) {
    //   _sendMessageWithFiles();
    //   return;
    // }

    final messageText = _messageController.text;
    _messageController.clear();

    bool wasAlert = _isAlert;
    bool wasEmergency = _isEmergency;

    setState(() {
      _isAlert = false;
      _isEmergency = false;
    });

    final optimisticMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      conversationId: widget.chatId,
      senderId: _currentUserId ?? 0,
      content: messageText,
      createdAt: DateTime.now(),
      readAt: null,
      files: [],
      messageType: 'text',
      isAlert: wasAlert,
      isEmergency: wasEmergency,
      updatedAt: DateTime.now(),
      status: [],
    );

    setState(() {
      _messages.insert(0, optimisticMessage);
    });

    try {
      final sentMessage = await _messageService.pasteMessages(
        'text',
        widget.chatId,
        [],
        messageText,
        wasAlert,
        wasEmergency,
      );

      if (sentMessage != null) {
        setState(() {
          final index = _messages.indexWhere(
            (m) =>
                m.id == optimisticMessage.id ||
                (m.content == optimisticMessage.content &&
                    m.createdAt
                            .difference(optimisticMessage.createdAt)
                            .inSeconds <
                        5),
          );

          if (index != -1) {
            _messages[index] = sentMessage;
          } else {
            _messages.insert(0, sentMessage);
          }
        });
      } else {
        setState(() {
          _messages.removeWhere((m) => m.id == optimisticMessage.id);
        });
        _showErrorSnackbar('Failed to send message');
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.removeWhere((m) => m.id == optimisticMessage.id);
      });
      _showErrorSnackbar('Network error. Please try again.');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onEmojiSelected(Emoji emoji) {
    _messageController.text = _messageController.text + emoji.emoji;
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                    'https://randomuser.me/api/portraits/men/32.jpg',
                  ),
                ),
                if (widget.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              widget.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.indigo),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                _isLoading && _messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _messages.length +
                          (_isLoading && _messages.isNotEmpty ? 1 : 0),
                      reverse: true,
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final message = _messages[index];
                        return _buildMessageItem(message);
                      },
                    ),
          ),

          // Message tag controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Alert tag toggle
                FilterChip(
                  label: const Text('Alert'),
                  selected: _isAlert,
                  selectedColor: Colors.amber.shade200,
                  avatar: Icon(
                    Icons.notifications_active,
                    color: _isAlert ? Colors.amber.shade800 : Colors.grey,
                    size: 16,
                  ),
                  onSelected: (_) => _toggleAlert(),
                ),
                const SizedBox(width: 8),
                // Emergency tag toggle
                FilterChip(
                  label: const Text('Emergency'),
                  selected: _isEmergency,
                  selectedColor: Colors.red.shade100,
                  avatar: Icon(
                    Icons.warning_rounded,
                    color: _isEmergency ? Colors.red : Colors.grey,
                    size: 16,
                  ),
                  onSelected: (_) => _toggleEmergency(),
                ),
              ],
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  spreadRadius: 1,
                  blurRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFilePreview(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: _toggleEmojiPicker,
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: _pickFiles,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Write a message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      mini: true,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                config: Config(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_selectedFiles.isEmpty) return SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];

          return Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    file.name.length > 10
                        ? '${file.name.substring(0, 10)}...'
                        : file.name,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedFiles.removeAt(index);
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final bool isMe = message.senderId == _currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 16,
          left: isMe ? 80 : 0,
          right: isMe ? 0 : 80,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(
                      'https://randomuser.me/api/portraits/men/32.jpg',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "you",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),

            // Message status indicators (Alert/Emergency)
            if (message.isAlert || message.isEmergency)
              Container(
                margin: EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: 12,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Alert',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (message.isAlert && message.isEmergency)
                      const SizedBox(width: 4),
                    if (message.isEmergency)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 12,
                              color: Colors.red.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Emergency',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Styling.getMessageBackgroundColor(message, isMe),
                borderRadius: BorderRadius.circular(16),
                border: Styling.getMessageBorder(message),
                boxShadow: [
                  BoxShadow(
                    color: Styling.getMessageShadowColor(message, isMe),
                    spreadRadius: message.isEmergency ? 2 : 1,
                    blurRadius: message.isEmergency ? 3 : 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File type indicator for file messages
                  if (message.files.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.files.length > 1
                                ? Icons.folder
                                : Styling.getFileIcon(
                                  message.files.first.mimeType,
                                ),
                            size: 12,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.files.length > 1
                                ? '${message.files.length} Files'
                                : Styling.getFileTypeLabel(
                                  message.files.first.mimeType,
                                ),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // File attachments preview
                  if (message.files.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          message.files.map((file) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Styling.getFileIcon(file.mimeType),
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          DateFormatter.formatFileSize(
                                            file.fileSize,
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),

                  // Message text
                  if ((message.content ?? '').isNotEmpty)
                    Text(
                      message.content ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                ],
              ),
            ),

            // Timestamp and read status
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormatter.formatMessageTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (isMe)
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(
                          message.readAt != null ? Icons.done_all : Icons.done,
                          size: 14,
                          color:
                              message.readAt != null
                                  ? Colors.blue
                                  : Colors.grey.shade600,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
