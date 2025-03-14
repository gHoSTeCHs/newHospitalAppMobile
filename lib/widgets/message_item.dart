import 'package:flutter/material.dart';

class Message {
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isAlert;
  final bool isEmergency;
  final List<FileAttachment> files;
  final DateTime? readAt;

  Message({
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isAlert = false,
    this.isEmergency = false,
    this.files = const [],
    this.readAt,
  });
}

class FileAttachment {
  final String fileName;
  final String mimeType;
  final int fileSize;

  FileAttachment({
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });
}

class MessageItem extends StatelessWidget {
  final Message message;
  final String currentUserId;

  const MessageItem({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.senderId == currentUserId;

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
            if (!isMe) _buildSenderInfo(),
            const SizedBox(height: 4),
            if (message.isAlert || message.isEmergency) _buildAlertEmergency(),
            _buildMessageContent(isMe),
            _buildTimestamp(isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundImage: NetworkImage(
            'https://randomuser.me/api/portraits/men/32.jpg',
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "You",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAlertEmergency() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isAlert)
          _buildAlertBadge(
            icon: Icons.notifications_active,
            text: 'Alert',
            color: Colors.amber,
          ),
        if (message.isAlert && message.isEmergency) const SizedBox(width: 4),
        if (message.isEmergency)
          _buildAlertBadge(
            icon: Icons.warning_rounded,
            text: 'Emergency',
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildAlertBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.red.shade800),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(bool isMe) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.files.isNotEmpty) _buildFileAttachments(),
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileAttachments() {
    return Column(
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
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.blue),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          '${file.fileSize} KB',
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
    );
  }

  Widget _buildTimestamp(bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.createdAt.toString(),
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
    );
  }
}
