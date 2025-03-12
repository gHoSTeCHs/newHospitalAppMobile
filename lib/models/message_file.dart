class MessageFile {
  final int id;
  final int messageId;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageFile({
    required this.id,
    required this.messageId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a MessageFile instance from JSON
  factory MessageFile.fromJson(Map<String, dynamic> json) {
    return MessageFile(
      id: json['id'],
      messageId: json['message_id'],
      filePath: json['file_path'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Convert MessageFile instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
