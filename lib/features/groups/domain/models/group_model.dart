// Group Member Model
class GroupMember {
  final int partnerId;
  final String name;

  GroupMember({
    required this.partnerId,
    required this.name,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      partnerId: json['partner_id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner_id': partnerId,
      'name': name,
    };
  }
}

class GroupModel {
  final int channelId;
  final String name;
  final int memberCount;
  final List<GroupMember>? members;
  final String? description;
  final String? avatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  GroupModel({
    required this.channelId,
    required this.name,
    required this.memberCount,
    this.members,
    this.description,
    this.avatar,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      channelId: json['channel_id'] as int,
      name: json['group_name'] as String,
      memberCount: json['member_count'] as int,
      members: json['members'] != null
          ? (json['members'] as List)
              .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'group_name': name,
      'member_count': memberCount,
      'members': members?.map((m) => m.toJson()).toList(),
      'description': description,
      'avatar': avatar,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
    };
  }

  // For backward compatibility with UI
  String get id => channelId.toString();
}

// API Response Models
class GetAllGroupsResponse {
  final bool success;
  final int totalGroups;
  final List<GroupModel> groups;

  GetAllGroupsResponse({
    required this.success,
    required this.totalGroups,
    required this.groups,
  });

  factory GetAllGroupsResponse.fromJson(Map<String, dynamic> json) {
    return GetAllGroupsResponse(
      success: json['success'] as bool,
      totalGroups: json['total_groups'] as int,
      groups: (json['groups'] as List)
          .map((g) => GroupModel.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CreateGroupResponse {
  final bool success;
  final GroupModel group;

  CreateGroupResponse({
    required this.success,
    required this.group,
  });

  factory CreateGroupResponse.fromJson(Map<String, dynamic> json) {
    return CreateGroupResponse(
      success: json['success'] as bool,
      group: GroupModel.fromJson(json['group'] as Map<String, dynamic>),
    );
  }
}

class SendGroupMessageResponse {
  final bool success;
  final int messageId;
  final int groupId;
  final int attachmentCount;

  SendGroupMessageResponse({
    required this.success,
    required this.messageId,
    required this.groupId,
    required this.attachmentCount,
  });

  factory SendGroupMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendGroupMessageResponse(
      success: json['success'] as bool,
      messageId: json['message_id'] as int,
      groupId: json['group_id'] as int,
      attachmentCount: json['attachment_count'] as int,
    );
  }
}

class GroupMessage {
  final int messageId;
  final String body;
  final int senderId;
  final String senderName;
  final DateTime date;
  final bool isMe;
  final List<dynamic> attachments;

  GroupMessage({
    required this.messageId,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.date,
    required this.isMe,
    required this.attachments,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    // Parse author object
    final author = json['author'] as Map<String, dynamic>;
    
    return GroupMessage(
      messageId: json['id'] as int,
      body: json['body'] as String,
      senderId: author['id'] as int,
      senderName: author['name'] as String,
      date: DateTime.parse(json['date'] as String),
      isMe: json['is_me'] as bool,
      attachments: json['attachments'] as List<dynamic>,
    );
  }

  // Strip HTML tags from body
  String get plainBody {
    return body.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}

class GetGroupMessagesResponse {
  final bool success;
  final int channelId;
  final String channelName;
  final List<GroupMessage> messages;

  GetGroupMessagesResponse({
    required this.success,
    required this.channelId,
    required this.channelName,
    required this.messages,
  });

  factory GetGroupMessagesResponse.fromJson(Map<String, dynamic> json) {
    final channel = json['channel'] as Map<String, dynamic>;
    
    return GetGroupMessagesResponse(
      success: json['success'] as bool,
      channelId: channel['id'] as int,
      channelName: channel['name'] as String,
      messages: (channel['messages'] as List)
          .map((msg) => GroupMessage.fromJson(msg as Map<String, dynamic>))
          .toList(),
    );
  }
}
