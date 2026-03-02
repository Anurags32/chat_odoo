class ChannelModel {
  final int id;
  final String name;
  final int partnerId;
  final List<ChatMessageModel> messages;

  ChannelModel({
    required this.id,
    required this.name,
    required this.partnerId,
    required this.messages,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] as int,
      name: json['name'] as String,
      partnerId: json['partner_id'] as int,
      messages: (json['messages'] as List?)
              ?.map((msg) => ChatMessageModel.fromJson(msg as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'partner_id': partnerId,
      'messages': messages.map((msg) => msg.toJson()).toList(),
    };
  }

  ChannelModel copyWith({
    int? id,
    String? name,
    int? partnerId,
    List<ChatMessageModel>? messages,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      partnerId: partnerId ?? this.partnerId,
      messages: messages ?? this.messages,
    );
  }
}

class ChatMessageModel {
  final int id;
  final String body;
  final String date;
  final int? channelId;
  final MessageAuthor author;
  final bool? isMe;

  ChatMessageModel({
    required this.id,
    required this.body,
    required this.date,
    this.channelId,
    required this.author,
    this.isMe,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      body: json['body'] as String,
      date: json['date'] as String,
      channelId: json['channel_id'] as int?,
      author: MessageAuthor.fromJson(json['author'] as Map<String, dynamic>),
      isMe: json['is_me'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'date': date,
      if (channelId != null) 'channel_id': channelId,
      'author': author.toJson(),
      if (isMe != null) 'is_me': isMe,
    };
  }
}

class MessageAuthor {
  final int id;
  final String name;

  MessageAuthor({
    required this.id,
    required this.name,
  });

  factory MessageAuthor.fromJson(Map<String, dynamic> json) {
    return MessageAuthor(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ChannelResponse {
  final bool success;
  final ChannelModel channel;

  ChannelResponse({
    required this.success,
    required this.channel,
  });

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      success: json['success'] as bool,
      channel: ChannelModel.fromJson(json['channel'] as Map<String, dynamic>),
    );
  }
}

class SendMessageResponse {
  final bool success;
  final ChatMessageModel message;

  SendMessageResponse({
    required this.success,
    required this.message,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      success: json['success'] as bool,
      message: ChatMessageModel.fromJson(json['message'] as Map<String, dynamic>),
    );
  }
}
