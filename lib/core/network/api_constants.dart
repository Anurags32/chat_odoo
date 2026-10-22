class ApiConstants {
  // Base URLs
  static const String serverUrl = 'https://sanitizer-marsupial-delegator.ngrok-free.dev';
  static const String baseUrl = '$serverUrl/api';

  // WebSocket URL (Must use wss:// or ws:// scheme)
  static const String wsUrl = 'wss://sanitizer-marsupial-delegator.ngrok-free.dev/websocket';
  static const String wsOrigin = serverUrl;

  // Default Odoo Database
  static const String database = 'test18';

  // Odoo Session & WebRTC Endpoints (directly on serverUrl)
  static const String sessionAuthenticate = '$serverUrl/web/session/authenticate';
  static const String databaseList = '$serverUrl/web/database/list';

  // Custom webrtc_call module endpoints
  static const String webrtcIceServers = '$serverUrl/webrtc/ice_servers';
  static const String webrtcDeviceRegister = '$serverUrl/webrtc/device/register';
  static const String webrtcCallStart = '$serverUrl/webrtc/call/start';
  static const String webrtcCallAccept = '$serverUrl/webrtc/call/accept';
  static const String webrtcCallReject = '$serverUrl/webrtc/call/reject';
  static const String webrtcCallCancel = '$serverUrl/webrtc/call/cancel';
  static const String webrtcCallEnd = '$serverUrl/webrtc/call/end';
  static const String webrtcSignal = '$serverUrl/webrtc/signal';
  static const String webrtcCallHistory = '$serverUrl/webrtc/call/history';

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
}
