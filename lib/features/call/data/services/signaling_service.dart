import 'dart:async';
import 'dart:convert';
import '../../../../core/network/odoo_bus_service.dart';
import 'odoo_api.dart';
import 'rtc_logger.dart';

typedef PeerNotificationCallback = void Function(
  int senderSessionId,
  String event,
  Map<String, dynamic> payload,
  int sequence,
);

typedef RtcSessionsUpdateCallback = void Function(
  int channelId,
  dynamic rtcSessions,
);

typedef SessionEndedCallback = void Function(int sessionId);

/// Signaling Service for Odoo Discuss RTC
///
/// Uses the single unified OdooBusService to receive:
/// - discuss.channel.rtc.session/peer_notification (offer, answer, ice-candidate, trackChange, disconnect)
/// - discuss.channel/rtc_sessions_update
/// - discuss.channel.rtc.session/ended
///
/// Dispatches outbound signaling via OdooApi.notifyCallMembers() with 100ms debounced batching.
class SignalingService {
  final OdooApi _odooApi;
  final OdooBusService _bus = OdooBusService.instance;

  StreamSubscription? _peerNotifSub;
  StreamSubscription? _sessionEndedSub;
  StreamSubscription? _rtcSessionsSub;

  int _currentChannelId = 0;
  int? _selfSessionId;
  bool _disposed = false;

  // Outbound batching (100ms debounce like Odoo's peer_to_peer.js)
  final List<List<dynamic>> _outbox = [];
  bool _flushScheduled = false;

  PeerNotificationCallback? onPeerNotification;
  RtcSessionsUpdateCallback? onRtcSessionsUpdate;
  SessionEndedCallback? onSessionEnded;

  SignalingService(this._odooApi);

  bool get isConnected => _bus.status == BusStatus.connected;
  int get currentChannelId => _currentChannelId;

  /// Connect to the Odoo bus WebSocket and subscribe to channel & session channels
  Future<void> connect({required int channelId, int? selfSessionId}) async {
    _currentChannelId = channelId;
    _selfSessionId = selfSessionId;
    _disposed = false;

    // Subscribe to channel
    _bus.addChannel('discuss.channel_$channelId');
    _bus.addChannel('channel_$channelId');

    // If partner ID is known, add it
    if (_odooApi.partnerId != null && _odooApi.partnerId! > 0) {
      _bus.addChannel('res.partner_${_odooApi.partnerId}');
      _bus.addChannel('partner_${_odooApi.partnerId}');
    }

    if (selfSessionId != null && selfSessionId > 0) {
      _bus.addChannel('discuss.channel.rtc.session_$selfSessionId');
    }

    _setupListeners();
    await _bus.connect();
  }

  /// Update subscription once selfSessionId is acquired from join_call
  void updateSelfSessionId(int selfSessionId) {
    _selfSessionId = selfSessionId;
    RtcLogger.instance.log(
      'Subscribing bus to selfSessionId channel: discuss.channel.rtc.session_$selfSessionId',
      tag: 'SIGNAL-BUS',
    );
    _bus.addChannel('discuss.channel.rtc.session_$selfSessionId');
  }

  void _setupListeners() {
    _peerNotifSub?.cancel();
    _peerNotifSub = _bus.peerNotifications.listen((notif) {
      if (_disposed) return;
      if (notif.senderSessionId == _selfSessionId) return;

      RtcLogger.instance.log(
        'Incoming PEER_NOTIFICATION: event=${notif.event} from=${notif.senderSessionId} seq=${notif.sequence} payloadKeys=${notif.payload.keys.toList()}',
        tag: 'SIGNAL-BUS',
      );

      RtcLogger.instance.logIncomingSignaling(
        notif.event,
        details: 'sender=${notif.senderSessionId}, seq=${notif.sequence}',
      );

      onPeerNotification?.call(
        notif.senderSessionId,
        notif.event,
        notif.payload,
        notif.sequence,
      );
    });

    _sessionEndedSub?.cancel();
    _sessionEndedSub = _bus.sessionEnded.listen((sessionId) {
      if (_disposed) return;
      RtcLogger.instance.log('Incoming SESSION_ENDED: $sessionId', tag: 'SIGNAL-BUS');
      onSessionEnded?.call(sessionId);
    });

    _rtcSessionsSub?.cancel();
    _rtcSessionsSub = _bus.rtcSessionsUpdate.listen((data) {
      if (_disposed) return;
      final chId = data['id'] as int? ?? _currentChannelId;
      final rtcSessions = data['rtcSessions'];
      onRtcSessionsUpdate?.call(chId, rtcSessions);
    });
  }

  /// Outbound batching with 100ms debounce (like Odoo's peer_to_peer.js)
  void enqueueSignal({
    required int senderSessionId,
    required List<int> targetSessionIds,
    required int channelId,
    required String event,
    required dynamic payload,
    int sequence = 0,
  }) {
    if (targetSessionIds.isEmpty) return;
    _outbox.add([
      senderSessionId,
      targetSessionIds,
      jsonEncode({
        'event': event,
        'channelId': channelId,
        'payload': payload,
        'sequence': sequence,
      }),
    ]);

    RtcLogger.instance.logOutgoingSignaling(
      event,
      200,
      details: 'Queued to $targetSessionIds seq=$sequence (outbox: ${_outbox.length})',
    );

    if (!_flushScheduled) {
      _flushScheduled = true;
      Future.delayed(const Duration(milliseconds: 100), flushOutbox);
    }
  }

  /// Flush queued outbound signals immediately
  Future<void> flushOutbox() async {
    _flushScheduled = false;
    if (_outbox.isEmpty) return;
    final batch = List<List<dynamic>>.from(_outbox);
    _outbox.clear();
    try {
      final statusCode = await _odooApi.notifyCallMembers(peerNotifications: batch);
      RtcLogger.instance.log(
        'Flushed ${batch.length} notification(s) to Odoo, status: $statusCode',
        tag: 'SIGNAL-BUS',
      );
    } catch (e) {
      RtcLogger.instance.log('flushOutbox notify_call_members failed: $e', tag: 'SIGNAL-BUS');
    }
  }

  /// Send peer signaling message via OdooApi /mail/rtc/session/notify_call_members immediately
  Future<bool> sendSignal({
    required int senderSessionId,
    required List<int> targetSessionIds,
    required int channelId,
    required String event,
    required dynamic payload,
    int sequence = 0,
  }) async {
    final contentObj = {
      'event': event,
      'channelId': channelId,
      'payload': payload,
      'sequence': sequence,
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
      details: 'from: $senderSessionId -> to: $targetSessionIds seq: $sequence',
    );

    return statusCode == 200;
  }

  /// Disconnect and clean up
  Future<void> disconnect() async {
    _disposed = true;
    _flushScheduled = false;
    _outbox.clear();
    await _peerNotifSub?.cancel();
    await _sessionEndedSub?.cancel();
    await _rtcSessionsSub?.cancel();
    _peerNotifSub = null;
    _sessionEndedSub = null;
    _rtcSessionsSub = null;

    if (_currentChannelId > 0) {
      _bus.removeChannel('discuss.channel_$_currentChannelId');
      _bus.removeChannel('channel_$_currentChannelId');
    }
    if (_selfSessionId != null) {
      _bus.removeChannel('discuss.channel.rtc.session_$_selfSessionId');
    }

    RtcLogger.instance.log('SignalingService unsubscribed & disconnected.', tag: 'SIGNAL-BUS');
  }
}
