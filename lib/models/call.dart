import './call_participant.dart';

import 'user.dart';

class Call {
  final int id;
  final int conversationId;
  final int callerId;
  final String callType; // 'audio' or 'video'
  final String
  status; // 'initiated', 'ongoing', 'completed', 'missed', 'declined'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final User? caller;
  final List<CallParticipant>? participants;

  Call({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.callType,
    required this.status,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.caller,
    this.participants,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'],
      conversationId: json['conversation_id'],
      callerId: json['caller_id'],
      callType: json['call_type'],
      status: json['status'],
      startedAt:
          json['started_at'] != null
              ? DateTime.parse(json['started_at'])
              : null,
      endedAt:
          json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      caller: json['caller'] != null ? User.fromJson(json['caller']) : null,
      participants:
          json['participants'] != null
              ? (json['participants'] as List)
                  .map((participant) => CallParticipant.fromJson(participant))
                  .toList()
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'caller_id': callerId,
      'call_type': callType,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'caller': caller?.toJson(),
      'participants': participants?.map((p) => p.toJson()).toList(),
    };
  }

  // Calculate call duration in seconds
  int? getDurationInSeconds() {
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!).inSeconds;
    }
    return null;
  }

  // Format call duration as mm:ss
  String? getFormattedDuration() {
    final durationInSeconds = getDurationInSeconds();
    if (durationInSeconds == null) return null;

    final minutes = (durationInSeconds / 60).floor();
    final seconds = durationInSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
