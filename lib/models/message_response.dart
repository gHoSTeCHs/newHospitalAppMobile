import 'message.dart';

class MessagesResponse {
  final List<Message> messages;

  MessagesResponse({required this.messages});

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    return MessagesResponse(
      messages:
          (json['messages'] as List)
              .map((message) => Message.fromJson(message))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'messages': messages.map((message) => message.toJson()).toList()};
  }
}
