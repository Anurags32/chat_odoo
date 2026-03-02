class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://192.168.29.231:8030/api';

  // Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String users = '/chat/users';
  static const String createChannel = '/chat/channel';
  static const String sendMessage = '/chat/send';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
