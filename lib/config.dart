/// Odoo Discuss WebRTC Call Configuration
///
/// Use this file to configure your Odoo backend connection parameters.
/// Never hardcode 'localhost' because the mobile phone must reach Odoo over the network (e.g., via ngrok).
library;

class CallConfig {
  /// Base HTTPS ngrok URL for Odoo (never hardcode localhost)
  static const String defaultBaseUrl =
      'https://sanitizer-marsupial-delegator.ngrok-free.dev';

  /// Odoo Database Name
  static const String defaultDb = 'test18';

  /// Default Login Username / Email for the Flutter Buddy
  static const String defaultLogin = 'buddy@example.com';

  /// Default Password for the Flutter Buddy
  static const String defaultPassword = 'admin';

  /// Default Odoo Discuss Channel ID where Admin and Buddy connect
  static const int defaultChannelId = 1;

  /// Fallback STUN server when Odoo returns empty iceServers
  static const List<Map<String, dynamic>> stunFallback = [
    {
      'urls': ['stun:stun.l.google.com:19302'],
    },
  ];

  /// Timeout in seconds before issuing an automatic ICE diagnosis
  static const int iceTimeoutSeconds = 20;
}
