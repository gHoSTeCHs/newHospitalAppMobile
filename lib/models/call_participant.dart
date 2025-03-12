import 'user.dart';

class CallParticipant {
  final int id;
  final int callId;
  final int userId;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final User? user;

  CallParticipant({
    required this.id,
    required this.callId,
    required this.userId,
    this.joinedAt,
    this.leftAt,
    this.user,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      id: json['id'],
      callId: json['call_id'],
      userId: json['user_id'],
      joinedAt:
          json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'user_id': userId,
      'joined_at': joinedAt?.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'user': user?.toJson(),
    };
  }
}
