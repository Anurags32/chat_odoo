import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/storage/storage_service.dart';
import 'odoo_api.dart';
import 'rtc_logger.dart';

typedef PeerNotificationCallback = void Function(
  int senderSessionId,
  String event,
  Map<String, dynamic> payload,
);

typedef RtcSessionsUpdateCallback = void Function(
  int channelId,
  dynamic rtcSessions,
);

typedef SessionEndedCallback = void Function(int sessionId);

/// Signaling Service for Odoo Discuss RTC
///
/// Listens to Odoo WebSocket Bus notifications (/websocket) and delivers:
/// - discuss.channel.rtc.session/peer_notification (offer, answer, ice-candidate, disconnect)
/// - discuss.channel/rtc_sessions_update
/// - discuss.channel.rtc.session/ended
///
/// Sends peer signaling payloads via OdooApi.notifyCallMembers() with detailed logging.
class SignalingService {
  final OdooApi _odooApi;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  int _currentChannelId = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  PeerNotificationCallback? onPeerNotification;
  RtcSessionsUpdateCallback? onRtcSessionsUpdate;
  SessionEndedCallback? onSessionEnded;

  SignalingService(this._odooApi);

  bool get isConnected => _isConnected;

  String _deriveWsUrl(String baseUrl) {
    var wsUrl = '$baseUrl/websocket';
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }
    return wsUrl;
  }

  /// Connect to the Odoo bus WebSocket and subscribe to the channel
  Future<void> connect({required int channelId}) async {
    _currentChannelId = channelId;
    _disposed = false;

    await _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    if (_disposed) return;

    final baseUrl = _odooApi.baseUrl;
    final wsEndpoint = _deriveWsUrl(baseUrl);
    var sessionCookie = _odooApi.sessionCookie;
    if (sessionCookie == null || sessionCookie.isEmpty) {
      try {
        sessionCookie = await StorageService.instance.getSessionCookie();
      } catch (_) {}
    }

    RtcLogger.instance.log('Connecting to WebSocket Bus: $wsEndpoint...', tag: 'SIGNAL-BUS');

    try {
      final headers = <String, dynamic>{
        'Origin': baseUrl,
        'ngrok-skip-browser-warning': 'true',
      };

      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$sessionCookie';
      }

      final ioSocket = await WebSocket.connect(
        wsEndpoint,
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _channel = IOWebSocketChannel(ioSocket);
      _isConnected = true;

      RtcLogger.instance.log('WebSocket Bus CONNECTED successfully.', tag: 'SIGNAL-BUS');

      // Send initial subscribe frame
      _sendSubscribeFrame();

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (err) {
          RtcLogger.instance.log('WebSocket Bus Stream ERROR: $err', tag: 'SIGNAL-BUS');
          _handleDisconnect();
        },
        onDone: () {
          RtcLogger.instance.log('WebSocket Bus CLOSED by server.', tag: 'SIGNAL-BUS');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      RtcLogger.instance.log('WebSocket Bus Connection ERROR: $e', tag: 'SIGNAL-BUS');
      _handleDisconnect();
    }
  }

  void _sendSubscribeFrame() {
    if (_channel == null) return;

    // In Odoo, channels can be formatted as discuss.channel_<id> or channel_<id>
    final channels = [
      'discuss.channel_$_currentChannelId',
      'channel_$_currentChannelId',
    ];

    final subscribeMsg = {
      'event_name': 'subscribe',
      'data': {
        'channels': channels,
        'last': 0,
      },
    };

    final payload = jsonEncode(subscribeMsg);
    RtcLogger.instance.log('Subscribing to channels: $channels', tag: 'SIGNAL-BUS');
    _channel?.sink.add(payload);
  }

  void _onMessageReceived(dynamic rawData) {
    try {
      final decoded = jsonDecode(rawData as String);

      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            _processBusNotification(item);
          }
        }
      } else if (decoded is Map) {
        _processBusNotification(decoded);
      }
    } catch (e) {
      RtcLogger.instance.log('Failed to parse bus frame: $e | raw: $rawData', tag: 'SIGNAL-BUS');
    }
  }

  void _processBusNotification(Map notification) {
    // In Odoo, notifications may have structure { "id": 1, "message": { "type": "...", "payload": ... } }
    dynamic message = notification['message'] ?? notification;
    if (message is String) {
      try {
        message = jsonDecode(message);
      } catch (_) {}
    }

    if (message is! Map) return;

    final type = message['type'] as String? ?? '';
    final payload = message['payload'];

    // 1. Peer notification (WebRTC offer / answer / ice-candidate)
    if (type == 'discuss.channel.rtc.session/peer_notification') {
      if (payload is Map) {
        final sender = payload['sender'] as int?;
        final notifications = payload['notifications'] as List?;

        if (sender != null && notifications != null) {
          for (final notifItem in notifications) {
            _dispatchPeerNotification(sender, notifItem);
          }
        }
      }
    }
    // 2. Active RTC sessions update in channel
    else if (type == 'discuss.channel/rtc_sessions_update' || type == 'mail.channel/rtc_sessions_update') {
      RtcLogger.instance.logIncomingSignaling(type, details: payload);
      if (payload is Map) {
        final channelId = payload['id'] as int? ?? _currentChannelId;
        final rtcSessions = payload['rtcSessions'];
        onRtcSessionsUpdate?.call(channelId, rtcSessions);
      }
    }
    // 3. RTC session ended
    else if (type == 'discuss.channel.rtc.session/ended') {
      RtcLogger.instance.logIncomingSignaling(type, details: payload);
      if (payload is Map) {
        final sessionId = payload['sessionId'] as int?;
        if (sessionId != null) {
          onSessionEnded?.call(sessionId);
        }
      }
    }
  }

  void _dispatchPeerNotification(int senderSessionId, dynamic notifContent) {
    try {
      Map<String, dynamic> parsed;
      if (notifContent is String) {
        parsed = jsonDecode(notifContent) as Map<String, dynamic>;
      } else if (notifContent is Map) {
        parsed = notifContent.cast<String, dynamic>();
      } else {
        return;
      }

      final event = parsed['event'] as String? ?? 'unknown';
      final payload = (parsed['payload'] as Map?)?.cast<String, dynamic>() ?? {};

      RtcLogger.instance.logIncomingSignaling(
        event,
        details: 'sender=$senderSessionId, keys=${payload.keys.toList()}',
      );

      onPeerNotification?.call(senderSessionId, event, payload);
    } catch (e) {
      RtcLogger.instance.log('Failed to dispatch peer notification: $e', tag: 'SIGNAL-BUS');
    }
  }

  /// Send peer signaling message via OdooApi /mail/rtc/session/notify_call_members
  Future<bool> sendSignal({
    required int senderSessionId,
    required List<int> targetSessionIds,
    required int channelId,
    required String event,
    required dynamic payload,
  }) async {
    final contentObj = {
      'event': event,
      'channelId': channelId,
      'payload': payload,
    };

    final contentJson = jsonEncode(contentObj);

    final peerNotifications = [
      [
        senderSessionId,
        targetSessionIds,
        contentJson,
      ]
    ];

    final statusCode = await _odooApi.notifyCallMembers(peerNotifications: peerNotifications);

    RtcLogger.instance.logOutgoingSignaling(
      event,
      statusCode,
      details: 'from: $senderSessionId -> to: $targetSessionIds in channel: $channelId',
    );

    return statusCode == 200;
  }

  void _handleDisconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    if (!_disposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 4), () {
        if (!_disposed && !_isConnected) {
          RtcLogger.instance.log('Attempting WebSocket Bus reconnection...', tag: 'SIGNAL-BUS');
          _connectWebSocket();
        }
      });
    }
  }

  /// Disconnect and clean up
  Future<void> disconnect() async {
    _disposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    RtcLogger.instance.log('SignalingService disconnected.', tag: 'SIGNAL-BUS');
  }
}
