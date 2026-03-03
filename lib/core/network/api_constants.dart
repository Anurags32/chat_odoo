class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://192.168.29.231:8030/api';

  // Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String users = '/chat/users';
  static const String createChannel = '/chat/channel';
  static const String sendMessage = '/chat/send';
  
  // Group endpoints
  static const String createGroup = '/chat/group/create';
  static const String sendGroupMessage = '/chat/group/send';
  static const String getGroupMessages = '/chat/group/messages';
  static const String getAllGroups = '/chat/groups';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
