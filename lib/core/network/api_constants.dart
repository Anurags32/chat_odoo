import 'dio_client.dart';

class ApiConstants {
  // Default fallback server and database
  static String _serverUrl =
      'https://sanitizer-marsupial-delegator.ngrok-free.dev';
  static String _database = 'test18';

  static String get serverUrl => _serverUrl;
  static String get database => _database;

  static String get baseUrl => '$_serverUrl/api';

  static const String wsVersion = '18.0-7';

  // WebSocket URL (Must use wss:// or ws:// scheme with Odoo 18 version query param)
  static String get wsUrl {
    String url = '$_serverUrl/websocket?version=$wsVersion';
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'ws://');
    }
    return url;
  }

  static String get wsOrigin => _serverUrl;

  // Odoo Session & WebRTC Endpoints
  static String get sessionAuthenticate => '$_serverUrl/web/session/authenticate';
  static String get databaseList => '$_serverUrl/web/database/list';
  static String get webrtcPingChannel => '$_serverUrl/discuss/channel/ping';

  // Custom webrtc_call module endpoints
  static String get webrtcIceServers => '$_serverUrl/webrtc/ice_servers';
  static String get webrtcDeviceRegister => '$_serverUrl/webrtc/device/register';
  static String get webrtcCallStart => '$_serverUrl/webrtc/call/start';
  static String get webrtcCallAccept => '$_serverUrl/webrtc/call/accept';
  static String get webrtcCallReject => '$_serverUrl/webrtc/call/reject';
  static String get webrtcCallCancel => '$_serverUrl/webrtc/call/cancel';
  static String get webrtcCallEnd => '$_serverUrl/webrtc/call/end';
  static String get webrtcSignal => '$_serverUrl/webrtc/signal';
  static String get webrtcCallHistory => '$_serverUrl/webrtc/call/history';

  // Endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String saveFcmToken = '/save_fcm_token';
  static const String users = '/chat/users';
  static const String createChannel = '/chat/channel';
  static const String sendMessage = '/chat/send';

  // Group endpoints
  static const String createGroup = '/chat/group/create';
  static const String sendGroupMessage = '/chat/group/send';
  static const String getGroupMessages = '/chat/group/messages';
  static const String getAllGroups = '/chat/groups';
  static const String leaveGroup = '/chat/group/leave';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Dynamically update server URL and database from user login or saved settings
  static void updateConfig({String? serverUrl, String? database}) {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      String trimmed = serverUrl.trim();
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        trimmed = 'https://$trimmed';
      }
      _serverUrl = trimmed;
    }
    if (database != null && database.trim().isNotEmpty) {
      _database = database.trim();
    }
    DioClient.instance.updateBaseUrl(baseUrl);
  }
}
