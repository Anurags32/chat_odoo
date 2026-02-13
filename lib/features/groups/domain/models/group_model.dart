class GroupModel {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      avatar: json['avatar'] as String,
      memberIds: List<String>.from(json['memberIds'] as List),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
    };
  }

  int get memberCount => memberIds.length;
}
