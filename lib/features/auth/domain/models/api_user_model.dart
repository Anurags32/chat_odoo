class ApiUserModel {
  final int id;
  final String name;
  final String? email; // can be false (bool) from Odoo when not set
  final int partnerId;
  final String? avatar; // Base64 encoded image string
  final String imStatus;
  final DateTime? lastMessageDate;

  ApiUserModel({
    required this.id,
    required this.name,
    this.email,
    required this.partnerId,
    this.avatar,
    required this.imStatus,
    this.lastMessageDate,
  });

  factory ApiUserModel.fromJson(Map<String, dynamic> json) {
    // Odoo returns false (bool) when email is not set — treat as null
    final rawEmail = json['email'];
    final String? email =
        (rawEmail != null && rawEmail is String) ? rawEmail : null;

    // last_message_date is a string or null
    final rawDate = json['last_message_date'];
    final DateTime? lastMessageDate =
        (rawDate != null && rawDate is String) ? DateTime.tryParse(rawDate) : null;

    return ApiUserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: email,
      partnerId: json['partner_id'] as int,
      avatar: json['avatar'] as String?,
      imStatus: json['im_status'] as String,
      lastMessageDate: lastMessageDate,
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
      'last_message_date': lastMessageDate?.toIso8601String(),
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
