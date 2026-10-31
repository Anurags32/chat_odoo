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
  static const int defaultChannelId = 4;

  /// Fallback STUN servers when Odoo mail.ice.server returns empty
  static const List<Map<String, dynamic>> stunFallback = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
        'stun:stun.cloudflare.com:3478',
      ],
    },
  ];

  /// Fallback TURN servers used when Odoo mail.ice.server does not provide active TURN credentials.
  /// Configure your Coturn, Metered, or Twilio TURN credentials here or in Odoo's mail.ice.server table.
  static const List<Map<String, dynamic>> turnFallback = [
    // Example Coturn or custom TURN relay configuration:
    // {
    //   'urls': [
    //     'turn:your-turn-domain.com:3478?transport=udp',
    //     'turn:your-turn-domain.com:3478?transport=tcp',
    //     'turns:your-turn-domain.com:5349?transport=tcp',
    //   ],
    //   'username': 'your-turn-username',
    //   'credential': 'your-turn-password',
    // },
  ];

  /// Timeout in seconds before issuing an automatic ICE diagnosis
  static const int iceTimeoutSeconds = 20;
}
