class ApiUserModel {
  final int id;
  final String name;
  final String email;
  final int partnerId;
  final String? avatar; // Base64 encoded image string
  final String imStatus;

  ApiUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.partnerId,
    this.avatar,
    required this.imStatus,
  });

  factory ApiUserModel.fromJson(Map<String, dynamic> json) {
    return ApiUserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      partnerId: json['partner_id'] as int,
      avatar: json['avatar'] as String?,
      imStatus: json['im_status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'partner_id': partnerId,
      'avatar': avatar,
      'im_status': imStatus,
    };
  }

  bool get isOnline => imStatus == 'online';
  bool get isActive => imStatus != 'offline';
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
}

class UsersResponse {
  final bool success;
  final List<ApiUserModel> users;

  UsersResponse({
    required this.success,
    required this.users,
  });

  factory UsersResponse.fromJson(Map<String, dynamic> json) {
    return UsersResponse(
      success: json['success'] as bool,
      users: (json['users'] as List)
          .map((user) => ApiUserModel.fromJson(user as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }
}
