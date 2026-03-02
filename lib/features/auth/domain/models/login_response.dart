class LoginResponse {
  final String status;
  final int userId;
  final String userName;
  final String sessionToken;
  final String expiryTime;

  LoginResponse({
    required this.status,
    required this.userId,
    required this.userName,
    required this.sessionToken,
    required this.expiryTime,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>;
    return LoginResponse(
      status: result['status'] as String,
      userId: result['user_id'] as int,
      userName: result['user_name'] as String,
      sessionToken: result['session_token'] as String,
      expiryTime: result['expiry_time'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'user_id': userId,
      'user_name': userName,
      'session_token': sessionToken,
      'expiry_time': expiryTime,
    };
  }
}
