class UserModel {
  final String id;
  final String name;
  final String avatar;
  final String status;
  final bool isOnline;
  final String? lastSeen;
  final String? profilePicture; // URL for profile picture

  UserModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.status,
    this.isOnline = false,
    this.lastSeen,
    this.profilePicture,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String,
      status: json['status'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] as String?,
      profilePicture: json['profilePicture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'status': status,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'profilePicture': profilePicture,
    };
  }
}
