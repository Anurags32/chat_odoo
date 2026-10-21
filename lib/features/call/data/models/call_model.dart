enum CallType {
  audio,
  video;

  String toJson() => name;
  static CallType fromJson(String? value) =>
      value == 'video' ? CallType.video : CallType.audio;
}

enum CallState {
  idle,
  ringing,
  accepted,
  connecting,
  connected,
  rejected,
  missed,
  ended,
  busy,
  failed,
  cancelled,
}

class CallParticipant {
  final int partnerId;
  final String name;
  final String? email;
  final String? avatarUrl;

  CallParticipant({
    required this.partnerId,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      partnerId: json['partner_id'] is int ? json['partner_id'] : int.tryParse(json['partner_id'].toString()) ?? 0,
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'partner_id': partnerId,
    'name': name,
    'email': email,
  };
}

class CallModel {
  final int id;
  final CallType callType;
  final CallState state;
  final DateTime startTime;
  final DateTime? answerTime;
  final DateTime? endTime;
  final int duration;
  final String? durationFormatted;
  final String? endReason;
  final CallParticipant caller;
  final CallParticipant callee;

  CallModel({
    required this.id,
    required this.callType,
    required this.state,
    required this.startTime,
    this.answerTime,
    this.endTime,
    this.duration = 0,
    this.durationFormatted,
    this.endReason,
    required this.caller,
    required this.callee,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    CallType type = CallType.audio;
    if (json['call_type'] == 'video') {
      type = CallType.video;
    }

    CallState state = CallState.idle;
    switch (json['state']) {
      case 'ringing':
        state = CallState.ringing;
        break;
      case 'accepted':
        state = CallState.accepted;
        break;
      case 'rejected':
        state = CallState.rejected;
        break;
      case 'missed':
        state = CallState.missed;
        break;
      case 'ended':
        state = CallState.ended;
        break;
      case 'busy':
        state = CallState.busy;
        break;
      case 'failed':
        state = CallState.failed;
        break;
      case 'cancelled':
        state = CallState.cancelled;
        break;
      default:
        state = CallState.idle;
    }

    return CallModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      callType: type,
      state: state,
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) ?? DateTime.now() : DateTime.now(),
      answerTime: json['answer_time'] != null ? DateTime.tryParse(json['answer_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      durationFormatted: json['duration_formatted'] as String?,
      endReason: json['end_reason'] as String?,
      caller: CallParticipant.fromJson(json['caller'] as Map<String, dynamic>? ?? {}),
      callee: CallParticipant.fromJson(json['callee'] as Map<String, dynamic>? ?? {}),
    );
  }

  CallModel copyWith({
    CallState? state,
    DateTime? answerTime,
    DateTime? endTime,
    int? duration,
    String? durationFormatted,
    String? endReason,
  }) {
    return CallModel(
      id: id,
      callType: callType,
      state: state ?? this.state,
      startTime: startTime,
      answerTime: answerTime ?? this.answerTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      endReason: endReason ?? this.endReason,
      caller: caller,
      callee: callee,
    );
  }
}
