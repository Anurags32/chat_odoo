import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../storage/storage_service.dart';
import 'api_constants.dart';

/// Connection statuses for the unified Odoo Bus
enum BusStatus { disconnected, connecting, connected, error }

/// Parsed peer notification received over the bus
class OdooPeerNotification {
  final int senderSessionId;
  final String event; // offer, answer, ice-candidate, trackChange, disconnect
  final int channelId;
  final Map<String, dynamic> payload;
  final int sequence;

  OdooPeerNotification({
    required this.senderSessionId,
    required this.event,
    required this.channelId,
    required this.payload,
    required this.sequence,
  });

  @override
  String toString() =>
      'OdooPeerNotification(sender: $senderSessionId, event: $event, channel: $channelId, seq: $sequence)';
}

/// Unified Odoo WebSocket Bus Service (SINGLE shared connection for Chat and RTC Calls)
class OdooBusService {
  static final OdooBusService instance = OdooBusService._internal();

  OdooBusService._internal();

  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;

  BusStatus _status = BusStatus.disconnected;
  BusStatus get status => _status;

  final Set<String> _channels = <String>{};
  int _lastNotificationId = 0;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  // Broadcast streams
  final _busEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get busEvents => _busEventsController.stream;

  final _peerNotificationController = StreamController<OdooPeerNotification>.broadcast();
  Stream<OdooPeerNotification> get peerNotifications => _peerNotificationController.stream;

  final _sessionEndedController = StreamController<int>.broadcast();
  Stream<int> get sessionEnded => _sessionEndedController.stream;

  final _rtcSessionsUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rtcSessionsUpdate => _rtcSessionsUpdateController.stream;

  final _statusController = StreamController<BusStatus>.broadcast();
  Stream<BusStatus> get statusStream => _statusController.stream;

  // Callbacks for legacy/direct listeners
  void Function(BusStatus)? onStatusChange;
  void Function(List<dynamic>)? onRawMessages;

  /// Add a channel to the bus subscription (e.g. 'discuss.channel_1', 'discuss.channel.rtc.session_70')
  void addChannel(String channel) {
    if (channel.isEmpty) return;
    if (_channels.add(channel)) {
      debugPrint('[BUS] Added subscription channel: $channel (total: ${_channels.length})');
      if (_status == BusStatus.connected) {
        _sendSubscribeFrame();
      } else if (_status == BusStatus.disconnected && !_isDisposed) {
        connect();
      }
    }
  }

  /// Remove a channel from subscription
  void removeChannel(String channel) {
    if (_channels.remove(channel)) {
      debugPrint('[BUS] Removed subscription channel: $channel (remaining: ${_channels.length})');
      if (_status == BusStatus.connected && _channels.isNotEmpty) {
        _sendSubscribeFrame();
      }
    }
  }

  /// Explicitly set or add multiple channels
  void setChannels(Iterable<String> channels) {
    _channels.addAll(channels.where((c) => c.isNotEmpty));
    if (_status == BusStatus.connected) {
      _sendSubscribeFrame();
    } else if (_status == BusStatus.disconnected && !_isDisposed) {
      connect();
    }
  }

  /// Connect to Odoo WebSocket bus
  Future<void> connect() async {
    if (_status == BusStatus.connecting || _status == BusStatus.connected) {
      return;
    }

    _isDisposed = false;
    _setStatus(BusStatus.connecting);

    try {
      final sessionCookie = await StorageService.instance.getSessionCookie();
      final partnerId = await StorageService.instance.getPartnerId();

      // Automatically ensure user's partner channel is in subscriptions
      if (partnerId != null && partnerId > 0) {
        _channels.add('res.partner_$partnerId');
        _channels.add('partner_$partnerId');
      }

      final wsEndpoint = ApiConstants.wsUrl;
      final origin = ApiConstants.wsOrigin;

      debugPrint('[BUS] Connecting to WebSocket: $wsEndpoint (Cookie: session_id=${sessionCookie != null ? "PRESENT" : "MISSING"})');

      final headers = <String, dynamic>{
        'Origin': origin,
        'ngrok-skip-browser-warning': 'true',
      };

      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = 'session_id=$sessionCookie';
      }

      _socket = await WebSocket.connect(wsEndpoint, headers: headers).timeout(const Duration(seconds: 12));
      _reconnectAttempts = 0;
      _setStatus(BusStatus.connected);
      debugPrint('[BUS] WebSocket Connected successfully.');

      // Send subscription frame with current channel set and last notification ID
      _sendSubscribeFrame();

      _subscription = _socket!.listen(
        _onDataReceived,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      // Keepalive byte 0x00 every 50 seconds (Odoo websocket_worker standard)
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 50), (_) {
        try {
          _socket?.add(Uint8List.fromList([0]));
          debugPrint('[BUS] Sent keepalive ping (0x00)');
        } catch (e) {
          debugPrint('[BUS] Keepalive failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[BUS] Connection failed: $e');
      _setStatus(BusStatus.error);
      _scheduleReconnect();
    }
  }

  void _sendSubscribeFrame() {
    if (_socket == null || _status != BusStatus.connected) return;

    final subscribeMsg = {
      'event_name': 'subscribe',
      'data': {
        'channels': _channels.toList(),
        'last': _lastNotificationId,
      },
    };

    final payload = jsonEncode(subscribeMsg);
    debugPrint('[BUS] >>> SEND subscribe frame: channels=${_channels.toList()} last=$_lastNotificationId');
    try {
      _socket?.add(payload);
    } catch (e) {
      debugPrint('[BUS] Error sending subscribe frame: $e');
    }
  }

  void _onDataReceived(dynamic raw) {
    if (raw is! String) return; // Ignore binary ping/pong

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        onRawMessages?.call(decoded);
        for (final item in decoded) {
          if (item is Map) {
            final nid = item['id'];
            if (nid is int && nid > _lastNotificationId) {
              _lastNotificationId = nid;
            }
            _processBusFrame(item.cast<String, dynamic>());
          }
        }
      } else if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final nid = map['id'];
        if (nid is int && nid > _lastNotificationId) {
          _lastNotificationId = nid;
        }
        _processBusFrame(map);
      }
    } catch (e) {
      debugPrint('[BUS] Failed to decode bus frame: $e | raw: $raw');
    }
  }

  void _processBusFrame(Map<String, dynamic> frame) {
    _busEventsController.add(frame);

    dynamic message = frame['message'] ?? frame;
    if (message is String) {
      try {
        message = jsonDecode(message);
      } catch (_) {}
    }

    if (message is! Map) return;
    final map = message.cast<String, dynamic>();
    final type = map['type'] as String? ?? '';
    final payload = map['payload'];

    // 1. Peer notification (WebRTC offer / answer / ice-candidate / trackChange / disconnect)
    if (type == 'discuss.channel.rtc.session/peer_notification') {
      debugPrint('[BUS] <<< discuss.channel.rtc.session/peer_notification received!');
      if (payload is Map) {
        final sender = payload['sender'] as int?;
        final notifications = payload['notifications'] as List?;
        if (sender != null && notifications != null) {
          for (final notif in notifications) {
            _dispatchPeerNotification(sender, notif);
          }
        }
      }
    }
    // 2. Active RTC sessions update
    else if (type == 'discuss.channel/rtc_sessions_update' ||
        type == 'mail.channel/rtc_sessions_update') {
      debugPrint('[BUS] <<< RTC sessions update: $payload');
      if (payload is Map) {
        _rtcSessionsUpdateController.add(payload.cast<String, dynamic>());
      }
    }
    // 3. Store insert (Odoo 18 style RTC sessions update)
    else if (type == 'mail.record/insert') {
      if (payload is Map) {
        final channels = payload['discuss.channel'] as List?;
        if (channels != null) {
          for (final ch in channels) {
            if (ch is Map && ch['rtcSessions'] != null) {
              _rtcSessionsUpdateController.add(ch.cast<String, dynamic>());
            }
          }
        }
      }
    }
    // 4. RTC session ended
    else if (type == 'discuss.channel.rtc.session/ended') {
      debugPrint('[BUS] <<< RTC session ended: $payload');
      if (payload is Map) {
        final sessionId = payload['sessionId'] as int?;
        if (sessionId != null) {
          _sessionEndedController.add(sessionId);
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
      final channelId = parsed['channelId'] as int? ?? 0;
      final payload = (parsed['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      final sequence = parsed['sequence'] as int? ?? 0;

      final notif = OdooPeerNotification(
        senderSessionId: senderSessionId,
        event: event,
        channelId: channelId,
        payload: payload,
        sequence: sequence,
      );

      debugPrint('[BUS] Dispatched Peer Notification: $notif');
      _peerNotificationController.add(notif);
    } catch (e) {
      debugPrint('[BUS] Failed to parse peer notification content: $e');
    }
  }

  void _handleError(dynamic err) {
    debugPrint('[BUS] WebSocket Stream Error: $err');
    _setStatus(BusStatus.error);
    _scheduleReconnect();
  }

  void _handleDone() {
    debugPrint('[BUS] WebSocket closed by server.');
    _setStatus(BusStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _keepAliveTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _socket = null;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 3) ? 2 : (_reconnectAttempts <= 6 ? 5 : 10);
    debugPrint('[BUS] Reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _status != BusStatus.connected) {
        connect();
      }
    });
  }

  void _setStatus(BusStatus status) {
    _status = status;
    _statusController.add(status);
    onStatusChange?.call(status);
  }

  /// Disconnect and dispose resources
  Future<void> disconnect() async {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    await _subscription?.cancel();
    await _socket?.close();
    _socket = null;
    _setStatus(BusStatus.disconnected);
    debugPrint('[BUS] Disconnected.');
  }
}
