// odoo_rtc_service.dart
//
// Odoo 18 peer_to_peer.js + websocket_worker.js Dart port (audio-only).
// Implemented with dart:io HttpClient (no extra package:http dependency required).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

const _defaultIceServers = [
  {
    'urls': ['stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302'],
  },
];

class _Peer {
  _Peer(this.id, this.pc, this.dc, this.hasPriority, this.sequence);
  final int id;
  final RTCPeerConnection pc;
  final RTCDataChannel dc;
  final bool hasPriority; // remote id > selfId (Odoo ka rule)
  final int sequence;
  bool isBuildingOffer = false;
  bool isBuildingAnswer = false;
  bool ready = false; // remote ka "broadcast" data-channel msg aaya
  final List<RTCIceCandidate> pendingCandidates = [];
}

class OdooRtcService {
  OdooRtcService({
    required this.baseUrl, // https://xxxx.ngrok-free.dev (end me / nahi)
    required this.sessionId, // Odoo session_id cookie
    this.wsVersion = '18.0-7', // DevTools websocket?version=18.0-7
  });

  final String baseUrl;
  final String sessionId;
  final String wsVersion;

  // ---- callbacks (UI ke liye) ----
  void Function(String msg)? onLog;
  void Function(Map<String, dynamic> notification)? onBusEvent;
  void Function(int sessionId, MediaStream stream)? onRemoteStream;
  void Function(int sessionId, String state)? onPeerState;

  // ---- bus state ----
  WebSocket? _ws;
  Timer? _keepAlive;
  int _lastNotificationId = 0;
  bool _busStopped = false;

  // ---- call state ----
  int? _channelId;
  int? _selfId; // Rtc.selfSession
  List<Map<String, dynamic>> _iceServers = List.of(_defaultIceServers);
  MediaStream? _localStream;
  final Map<int, _Peer> _peers = {};
  Timer? _pingTimer;

  // inbound notifications ko order me process karne ke liye
  Future<void> _inbound = Future.value();

  // outbound batching (Odoo 100ms batch)
  final List<List<dynamic>> _outbox = [];
  bool _flushScheduled = false;

  void _log(String m) => onLog?.call('[rtc] $m');

  // =====================================================================
  // HTTP (JSON-RPC, cookie auth via dart:io HttpClient)
  // =====================================================================
  Future<dynamic> _rpc(String route, Map<String, dynamic> params) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl$route'));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('Cookie', 'session_id=$sessionId');
      req.headers.set('ngrok-skip-browser-warning', 'true');
      req.headers.set('Origin', baseUrl);
      req.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
      );
      final res = await req.close();
      final bodyStr = await res.transform(utf8.decoder).join();
      final body = jsonDecode(bodyStr);
      if (body is Map && body['error'] != null) {
        throw Exception('RPC $route failed: ${body['error']}');
      }
      return body is Map ? body['result'] : body;
    } finally {
      client.close();
    }
  }

  // =====================================================================
  // BUS WEBSOCKET (websocket_worker.js ka port)
  // =====================================================================
  Future<void> connectBus() async {
    _busStopped = false;
    final wsBase = baseUrl.startsWith('https')
        ? baseUrl.replaceFirst('https', 'wss')
        : baseUrl.replaceFirst('http', 'ws');
    final url = '$wsBase/websocket?version=$wsVersion';
    _log('bus connecting: $url');

    _ws = await WebSocket.connect(
      url,
      headers: {
        'Cookie': 'session_id=$sessionId',
        'Origin': baseUrl, // Odoo bina Origin ke 400 deta hai
        'ngrok-skip-browser-warning': 'true',
      },
    );

    _ws!.listen(
      _onBusMessage,
      onDone: () {
        _log('bus closed: ${_ws?.closeCode} ${_ws?.closeReason}');
        _keepAlive?.cancel();
        if (!_busStopped) {
          Future.delayed(const Duration(seconds: 3), () {
            if (!_busStopped) connectBus();
          });
        }
      },
      onError: (e) => _log('bus error: $e'),
    );

    // Worker subscription frame: channels: [] auto-subscribes partner channel
    _ws!.add(
      jsonEncode({
        'event_name': 'subscribe',
        'data': {'channels': [], 'last': _lastNotificationId},
      }),
    );

    // Worker sends 0x00 byte every 60s
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 60), (_) {
      try {
        _ws?.add(Uint8List.fromList([0]));
      } catch (_) {}
    });
  }

  void disconnectBus() {
    _busStopped = true;
    _keepAlive?.cancel();
    _ws?.close(1000);
    _ws = null;
  }

  void _onBusMessage(dynamic data) {
    if (data is! String) return;
    final list = jsonDecode(data);
    if (list is! List || list.isEmpty) return;
    for (final n in list) {
      _lastNotificationId = n['id'] ?? _lastNotificationId;
      final msg = n['message'];
      if (msg == null) continue;
      onBusEvent?.call(Map<String, dynamic>.from(n));

      final type = msg['type'];
      final payload = msg['payload'];
      if (type == 'discuss.channel.rtc.session/peer_notification') {
        final sender = payload['sender'];
        for (final content in (payload['notifications'] as List)) {
          _inbound = _inbound.then(
            (_) => _handleNotification(sender, content as String),
          );
        }
      }
    }
  }

  // =====================================================================
  // CALL: join / attach
  // =====================================================================

  Future<void> joinCall(int channelId, {int? invitationSessionId}) async {
    final data = await _rpc('/mail/rtc/channel/join_call', {
      'channel_id': channelId,
      'check_rtc_session_ids': invitationSessionId != null
          ? [invitationSessionId]
          : [],
      'camera': false,
    });
    await attachToCall(channelId, Map<String, dynamic>.from(data));
  }

  Future<void> attachToCall(int channelId, Map<String, dynamic> data) async {
    _channelId = channelId;
    final rtc = data['Rtc'] as Map;
    _selfId = rtc['selfSession'] as int;

    final ice = rtc['iceServers'];
    _iceServers = (ice is List && ice.isNotEmpty)
        ? ice.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : List.of(_defaultIceServers);

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false,
    });

    final others = _extractSessionIds(data, channelId)..remove(_selfId);
    _log('self=$_selfId, existing peers=$others');
    for (final id in others) {
      await _createPeer(id);
    }

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());
  }

  Set<int> _extractSessionIds(Map<String, dynamic> data, int channelId) {
    final ids = <int>{};
    final channels = data['discuss.channel'];
    if (channels is List) {
      for (final ch in channels) {
        if (ch['id'] != channelId) continue;
        final ops = ch['rtcSessions'];
        if (ops is! List) continue;
        for (final op in ops) {
          if (op is List && op.length == 2 && op[0] == 'ADD') {
            ids.addAll((op[1] as List).cast<int>());
          }
        }
      }
    }
    return ids;
  }

  Future<void> _ping() async {
    if (_channelId == null || _selfId == null) return;
    try {
      await _rpc('/discuss/channel/ping', {
        'channel_id': _channelId,
        'rtc_session_id': _selfId,
        'check_rtc_session_ids': _peers.keys.toList(),
      });
    } catch (e) {
      _log('ping failed: $e');
    }
  }

  Future<void> leaveCall() async {
    final ch = _channelId;
    if (ch == null) return;
    _enqueue('disconnect', null, _peers.keys.toList());
    await _flush();
    for (final id in _peers.keys.toList()) {
      await _removePeer(id);
    }
    _pingTimer?.cancel();
    await _localStream?.dispose();
    _localStream = null;
    try {
      await _rpc('/mail/rtc/channel/leave_call', {'channel_id': ch});
    } catch (e) {
      _log('leave_call failed: $e');
    }
    _channelId = null;
    _selfId = null;
  }

  Future<void> setMuted(bool muted) async {
    for (final t in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    _dcBroadcast('info', {
      'isSelfMuted': muted,
      'isRaisingHand': false,
      'isDeaf': false,
      'isTalking': false,
      'isCameraOn': false,
      'isScreenSharingOn': false,
    });
    try {
      await _rpc('/mail/rtc/session/update_and_broadcast', {
        'session_id': _selfId,
        'values': {'is_muted': muted},
      });
    } catch (e) {
      _log('update_and_broadcast failed: $e');
    }
  }

  // =====================================================================
  // PEER CREATION (_createPeer in peer_to_peer.js)
  // =====================================================================
  Future<_Peer> _createPeer(
    int id, {
    int sequence = 0,
    bool addTransceivers = true,
  }) async {
    await _removePeer(id);

    final pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });

    // Odoo: negotiated data channel, id 1, label "notifications"
    final dc = await pc.createDataChannel(
      'notifications',
      RTCDataChannelInit()
        ..negotiated = true
        ..id = 1,
    );

    final peer = _Peer(id, pc, dc, id > (_selfId ?? 0), sequence);
    _peers[id] = peer;

    // Odoo fixed transceiver order: audio, camera, screen
    if (addTransceivers) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      for (var i = 0; i < 2; i++) {
        await pc.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }
      await _attachLocalAudio(peer);
    }

    pc.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      if (!_peers.containsKey(id)) return;
      _enqueue('ice-candidate', {'candidate': c.toMap()}, [id]);
    };

    pc.onRenegotiationNeeded = () async {
      if (!_peers.containsKey(id)) return;
      if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable)
        return;
      peer.isBuildingOffer = true;
      try {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
      } catch (e) {
        peer.isBuildingOffer = false;
        _log('offer build failed: $e');
        return;
      }
      peer.isBuildingOffer = false;
      final local = await pc.getLocalDescription();
      if (local == null || !_peers.containsKey(id)) return;
      _enqueue(
        'offer',
        {
          'sdp': {'type': local.type, 'sdp': local.sdp},
          'sequence': peer.sequence,
        },
        [id],
      );
    };

    pc.onIceConnectionState = (s) => _log('peer $id ICE: $s');
    pc.onConnectionState = (s) {
      _log('peer $id PC: $s');
      onPeerState?.call(id, s.toString());
    };

    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) onRemoteStream?.call(id, e.streams.first);
    };

    dc.onMessage = (RTCDataChannelMessage m) {
      _inbound = _inbound.then((_) => _handleNotification(id, m.text));
    };
    dc.onDataChannelState = (RTCDataChannelState s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        // Odoo browser waits for "broadcast" before rendering audio
        _dcSend(peer, 'info', {
          'isSelfMuted': false,
          'isRaisingHand': false,
          'isDeaf': false,
          'isTalking': false,
          'isCameraOn': false,
          'isScreenSharingOn': false,
        });
        _dcSend(peer, 'broadcast', {'sequence': peer.sequence});
      }
    };

    return peer;
  }

  Future<void> _attachLocalAudio(_Peer peer) async {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null) return;
    final transceivers = await peer.pc.getTransceivers();
    if (transceivers.isEmpty) return;
    final audio = transceivers.first; // index 0 = audio
    await audio.sender.replaceTrack(track);
    await audio.setDirection(TransceiverDirection.SendRecv);
  }

  Future<void> _removePeer(int id) async {
    final peer = _peers.remove(id);
    if (peer == null) return;
    try {
      await peer.dc.close();
      await peer.pc.close();
    } catch (_) {}
  }

  // =====================================================================
  // INBOUND (handleNotification in peer_to_peer.js)
  // =====================================================================
  Future<void> _handleNotification(int senderId, String content) async {
    try {
      final msg = jsonDecode(content) as Map<String, dynamic>;
      final event = msg['event'] as String;
      final channelId = msg['channelId'];
      final payload = msg['payload'];
      if (channelId != _channelId) return;
      _log('<- $event from $senderId');

      var peer = _peers[senderId];
      if (event != 'offer' && peer == null) {
        _log('$event for missing peer $senderId');
        return;
      }

      switch (event) {
        case 'offer':
          await _onOffer(senderId, peer, payload);
          break;
        case 'answer':
          final st = peer!.pc.signalingState;
          if (st == RTCSignalingState.RTCSignalingStateStable ||
              st == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
            return;
          }
          await peer.pc.setRemoteDescription(
            RTCSessionDescription(
              payload['sdp']['sdp'],
              payload['sdp']['type'],
            ),
          );
          await _flushCandidates(peer);
          break;
        case 'ice-candidate':
          final c = payload['candidate'];
          final cand = RTCIceCandidate(
            c['candidate'],
            c['sdpMid'],
            c['sdpMLineIndex'],
          );
          if (await peer!.pc.getRemoteDescription() == null) {
            peer.pendingCandidates.add(cand);
          } else {
            await peer.pc.addCandidate(cand);
          }
          break;
        case 'broadcast':
          peer!.ready = true;
          break;
        case 'info':
          break;
        case 'disconnect':
          await _removePeer(senderId);
          break;
      }
    } catch (e, st) {
      _log('handleNotification error: $e\n$st');
    }
  }

  Future<void> _onOffer(int senderId, _Peer? existing, dynamic payload) async {
    final peer =
        existing ??
        await _createPeer(
          senderId,
          sequence: (payload['sequence'] ?? 0) as int,
          addTransceivers: false,
        );
    final pc = peer.pc;

    final isStable =
        pc.signalingState == RTCSignalingState.RTCSignalingStateStable ||
        peer.isBuildingAnswer;
    final collision = !isStable || peer.isBuildingOffer;
    if (collision) {
      if (peer.hasPriority) {
        _log('offer collision with $senderId: rollback');
        await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      } else {
        _log('offer collision with $senderId: ignoring (priority ours)');
        return;
      }
    }

    await pc.setRemoteDescription(
      RTCSessionDescription(payload['sdp']['sdp'], payload['sdp']['type']),
    );
    await _flushCandidates(peer);
    await _attachLocalAudio(peer);

    peer.isBuildingAnswer = true;
    try {
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
    } finally {
      peer.isBuildingAnswer = false;
    }
    final local = await pc.getLocalDescription();
    if (local == null || !_peers.containsKey(senderId)) return;
    _enqueue(
      'answer',
      {
        'sdp': {'type': local.type, 'sdp': local.sdp},
      },
      [senderId],
    );
  }

  Future<void> _flushCandidates(_Peer peer) async {
    for (final c in peer.pendingCandidates) {
      try {
        await peer.pc.addCandidate(c);
      } catch (e) {
        _log('addCandidate failed: $e');
      }
    }
    peer.pendingCandidates.clear();
  }

  // =====================================================================
  // OUTBOUND: /mail/rtc/session/notify_call_members
  // =====================================================================
  void _enqueue(
    String event,
    Map<String, dynamic>? payload,
    List<int> targets,
  ) {
    if (_selfId == null || targets.isEmpty) return;
    _outbox.add([
      _selfId,
      targets,
      jsonEncode({'event': event, 'channelId': _channelId, 'payload': payload}),
    ]);
    _log('-> $event to $targets');
    if (!_flushScheduled) {
      _flushScheduled = true;
      Future.delayed(const Duration(milliseconds: 100), _flush);
    }
  }

  Future<void> _flush() async {
    _flushScheduled = false;
    if (_outbox.isEmpty) return;
    final batch = List<List<dynamic>>.from(_outbox);
    _outbox.clear();
    try {
      await _rpc('/mail/rtc/session/notify_call_members', {
        'peer_notifications': batch,
      });
    } catch (e) {
      _log('notify_call_members failed: $e');
    }
  }

  // =====================================================================
  // DATA CHANNEL helpers
  // =====================================================================
  void _dcSend(_Peer peer, String event, Map<String, dynamic> payload) {
    peer.dc.send(
      RTCDataChannelMessage(
        jsonEncode({
          'event': event,
          'channelId': _channelId,
          'payload': payload,
        }),
      ),
    );
  }

  void _dcBroadcast(String event, Map<String, dynamic> payload) {
    for (final p in _peers.values) {
      _dcSend(p, event, payload);
    }
  }
}
