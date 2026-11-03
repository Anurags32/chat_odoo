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
      messages:
          (json['messages'] as List?)
              ?.map(
                (msg) => ChatMessageModel.fromJson(msg as Map<String, dynamic>),
              )
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
  final List<MessageAttachment> attachments;
  final String? replyToText;
  final String? replyToAuthor;
  final int? replyToId;
  final Map<String, int> reactions;
  final bool isForwarded;
  final bool isDeleted;
  final bool isPinned;
  final String deliveryStatus; // 'sending', 'sent', 'delivered', 'read'

  ChatMessageModel({
    required this.id,
    required this.body,
    required this.date,
    this.channelId,
    required this.author,
    this.isMe,
    this.attachments = const [],
    this.replyToText,
    this.replyToAuthor,
    this.replyToId,
    this.reactions = const {},
    this.isForwarded = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.deliveryStatus = 'read',
  });

  String get cleanBody => body.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // Parse attachments if present
    List<MessageAttachment> parsedAttachments = [];
    if (json['attachments'] != null && json['attachments'] is List) {
      parsedAttachments = (json['attachments'] as List)
          .map((a) => MessageAttachment.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    // Parse reactions map
    Map<String, int> parsedReactions = {};
    if (json['reactions'] != null && json['reactions'] is Map) {
      json['reactions'].forEach((k, v) {
        if (v is int) parsedReactions[k.toString()] = v;
      });
    }

    return ChatMessageModel(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      date: json['date'] as String? ?? DateTime.now().toIso8601String(),
      channelId: json['channel_id'] as int?,
      author: MessageAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ??
            {
              'id': json['sender_id'] ?? 0,
              'name': json['sender_name'] ?? 'User',
            },
      ),
      isMe: json['is_me'] as bool?,
      attachments: parsedAttachments,
      replyToText: json['reply_to_text'] as String?,
      replyToAuthor: json['reply_to_author'] as String?,
      replyToId: json['reply_to_id'] as int?,
      reactions: parsedReactions,
      isForwarded: json['is_forwarded'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      deliveryStatus: json['delivery_status'] as String? ?? 'read',
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
      'attachments': attachments.map((a) => a.toJson()).toList(),
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToAuthor != null) 'reply_to_author': replyToAuthor,
      if (replyToId != null) 'reply_to_id': replyToId,
      'reactions': reactions,
      'is_forwarded': isForwarded,
      'is_deleted': isDeleted,
      'is_pinned': isPinned,
      'delivery_status': deliveryStatus,
    };
  }

  ChatMessageModel copyWith({
    int? id,
    String? body,
    String? date,
    int? channelId,
    MessageAuthor? author,
    bool? isMe,
    List<MessageAttachment>? attachments,
    String? replyToText,
    String? replyToAuthor,
    int? replyToId,
    Map<String, int>? reactions,
    bool? isForwarded,
    bool? isDeleted,
    bool? isPinned,
    String? deliveryStatus,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      body: body ?? this.body,
      date: date ?? this.date,
      channelId: channelId ?? this.channelId,
      author: author ?? this.author,
      isMe: isMe ?? this.isMe,
      attachments: attachments ?? this.attachments,
      replyToText: replyToText ?? this.replyToText,
      replyToAuthor: replyToAuthor ?? this.replyToAuthor,
      replyToId: replyToId ?? this.replyToId,
      reactions: reactions ?? this.reactions,
      isForwarded: isForwarded ?? this.isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}

class MessageAuthor {
  final int id;
  final String name;
  final String? avatar;

  MessageAuthor({required this.id, required this.name, this.avatar});

  factory MessageAuthor.fromJson(Map<String, dynamic> json) {
    return MessageAuthor(
      id: (json['id'] is int)
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name'] as String? ?? 'User',
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, if (avatar != null) 'avatar': avatar};
  }
}

class MessageAttachment {
  final int? id;
  final String filename;
  final String mimetype;
  final String? data; // Base64 encoded file data
  final String? url;
  final int? fileSize;

  MessageAttachment({
    this.id,
    required this.filename,
    required this.mimetype,
    this.data,
    this.url,
    this.fileSize,
  });

  bool get isImage =>
      mimetype.startsWith('image/') ||
      filename.toLowerCase().endsWith('.jpg') ||
      filename.toLowerCase().endsWith('.jpeg') ||
      filename.toLowerCase().endsWith('.png') ||
      filename.toLowerCase().endsWith('.webp') ||
      filename.toLowerCase().endsWith('.gif');

  bool get isVideo =>
      mimetype.startsWith('video/') ||
      filename.toLowerCase().endsWith('.mp4') ||
      filename.toLowerCase().endsWith('.mov') ||
      filename.toLowerCase().endsWith('.mkv');

  bool get isAudio =>
      mimetype.startsWith('audio/') ||
      filename.toLowerCase().endsWith('.m4a') ||
      filename.toLowerCase().endsWith('.mp3') ||
      filename.toLowerCase().endsWith('.wav') ||
      filename.toLowerCase().endsWith('.aac') ||
      filename.toLowerCase().endsWith('.ogg');

  bool get isPdf =>
      mimetype.contains('pdf') || filename.toLowerCase().endsWith('.pdf');

  bool get isDocument => !isImage && !isVideo && !isAudio;

  String get formattedSize {
    if (fileSize == null || fileSize! <= 0) {
      if (data != null && data!.isNotEmpty) {
        // Approximate size from base64 string
        final approxBytes = (data!.length * 3) ~/ 4;
        return _formatBytes(approxBytes);
      }
      return '';
    }
    return _formatBytes(fileSize!);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as int?,
      filename:
          json['filename'] as String? ?? json['name'] as String? ?? 'file',
      mimetype:
          json['mimetype'] as String? ??
          json['content_type'] as String? ??
          'application/octet-stream',
      data: json['data'] as String?,
      url: json['url'] as String?,
      fileSize: json['file_size'] as int? ?? json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'filename': filename,
      'mimetype': mimetype,
      if (data != null) 'data': data,
      if (url != null) 'url': url,
      if (fileSize != null) 'file_size': fileSize,
    };
  }
}

class ChannelResponse {
  final bool success;
  final ChannelModel channel;

  ChannelResponse({required this.success, required this.channel});

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      success: json['success'] as bool? ?? true,
      channel: ChannelModel.fromJson(json['channel'] as Map<String, dynamic>),
    );
  }
}

class SendMessageResponse {
  final bool success;
  final int messageId;
  final int attachmentCount;
  final ChatMessageModel? message;

  SendMessageResponse({
    required this.success,
    required this.messageId,
    required this.attachmentCount,
    this.message,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      success: json['success'] as bool? ?? true,
      messageId: json['message_id'] as int? ?? 0,
      attachmentCount: json['attachment_count'] as int? ?? 0,
      message: json['message'] != null
          ? ChatMessageModel.fromJson(json['message'] as Map<String, dynamic>)
          : null,
    );
  }
}
