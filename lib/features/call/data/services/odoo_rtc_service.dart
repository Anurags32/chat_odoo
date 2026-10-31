// odoo_rtc_service.dart  (v2)
//
// Odoo 18 ke rtc_service.js + peer_to_peer.js + rtc_session_model.js ka Dart port
// (audio-only). Public API pehle jaisi hi hai: connectBus, disconnectBus,
// joinCall, attachToCall, leaveCall, setMuted, callbacks.
//
// v1 se kya badla (search: "V2"):
//  1. Answerer fix: Odoo ka PEHLA offer sirf data-channel ka hota hai. Jo answer
//     deta hai wahi audio/video transceivers add karta hai aur media wala
//     naya offer bhejta hai. v1 me ye missing tha => ICE connect, par awaaz nahi.
//  2. Sequence rule: offer ka sequence browser ke session.sequence se kam nahi
//     hona chahiye, warna browser offer chupchap reject karta hai.
//  3. Event handlers peer banate hi lag jaate hain (negotiationneeded miss na ho).
//  4. ping ka response use hota hai (naye/gaye sessions sync), jaise browser
//     har 30s me ping() + call() karta hai.
//  5. Bus event discuss.channel.rtc.session/ended handle hota hai.
//  6. Chhota recovery: PC failed/disconnected rehne par peer dobara banta hai.
//  7. Speakerphone connect hote hi on, aur remote track bina stream ke aaye
//     to bhi handle.
//
// UNVERIFIED (maine source me nahi dekha): bus event
// 'discuss.channel.rtc.session/peer_notification' ka payload {sender, notifications[]}.
// Agar ICE connect ho raha hai to ye sahi hai (signaling chal rahi hai).
//
// ---------------------------------------------------------------------
// USE KAISE KARE (sirf AUDIO call, dono directions)
//
// 1) Login ke baad ek baar (connectBus() MAT chalao, shared bus use ho raha hai):
//      final rtc = OdooRtcService(baseUrl: ApiConstants.serverUrl, sessionId: cookie);
//      OdooBusService.instance.peerNotifications.listen((n) => rtc.handlePeerNotification(
//          sender: n.senderSessionId, event: n.event,
//          channelId: n.channelId, payload: n.payload));
//      OdooBusService.instance.sessionEnded.listen(rtc.handleSessionEnded);
//      rtc.onCallEnded = () { /* call screen band karo */ };
// 2) Call karna (caller):   await rtc.joinCall(channelId);
// 3) Call uthana (callee):  await rtc.joinCall(channelId, invitationSessionId: pushSessionId);
// 4) Reject karna:          await rtc.declineCall(channelId);
// 5) Call kaatna:           await rtc.leaveCall();
// 6) Mute:                  await rtc.setMuted(true);
// channelId = discuss.channel ka id (partner id / user id NAHI).
// cookie = /web/session/authenticate se mili LATEST session_id.
// ---------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../config.dart';

const List<Map<String, dynamic>> _defaultIceServers = CallConfig.stunFallback;

class _Peer {
  _Peer(this.id, this.pc, this.dc, this.hasPriority, this.sequence);
  final int id;
  final RTCPeerConnection pc;
  final RTCDataChannel dc;
  final bool
  hasPriority; // remote id > selfId => glare me remote ka offer jeetega
  final int sequence;
  bool isBuildingOffer = false;
  bool isBuildingAnswer = false;
  bool ready = false; // remote ka "broadcast" data-channel msg aaya
  final List<RTCIceCandidate> pendingCandidates = [];
}

class _EarlyNotif {
  _EarlyNotif(this.sender, this.content, this.at);
  final int sender;
  final String content;
  final DateTime at;
}

class OdooRtcService {
  OdooRtcService({
    required this.baseUrl, // https://xxxx.ngrok-free.dev (end me / nahi)
    required this.sessionId, // Odoo session_id cookie (LATEST wali)
    this.wsVersion = '18.0-7',
  });

  final String baseUrl;
  String sessionId; // cookie rotate ho to naya set karo
  final String wsVersion;

  // ---- callbacks (UI ke liye) ----
  void Function(String msg)? onLog;
  void Function(Map<String, dynamic> notification)? onBusEvent;
  void Function(int sessionId, MediaStream stream)? onRemoteStream;
  void Function(int sessionId, String state)? onPeerState;

  /// Server ne hamara session hata diya (bus event 'ended'). UI me call band karo.
  void Function()? onCallEnded;

  bool speakerOn = true;

  /// Peer banana/hatana aur notifications ek hi line me chalein (race na ho).
  /// NOTE: _handleNotification ke andar se _serial() mat bulao (deadlock).
  Future<T> _serial<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _inbound = _inbound.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ---- sequence (V2) ----
  // Odoo ka getSequence(): chhota, badhta hua int. Bahut bada number mat do,
  // warna browser "track received for old sequence" bol ke track drop kar deta hai.
  static int _sequenceCounter = 0;
  int _nextSequence() => ++_sequenceCounter;

  // ---- bus state ----
  WebSocket? _ws;
  Timer? _keepAlive;
  int _lastNotificationId = 0;
  bool _busStopped = false;

  // ---- call state ----
  int? _channelId;
  int? _selfId; // Rtc.selfSession
  List<Map<String, dynamic>> _iceServers = List<Map<String, dynamic>>.of(
    _defaultIceServers,
  );
  MediaStream? _localStream;
  final Map<int, _Peer> _peers = {};
  final Map<int, MediaStream> _remoteStreams = {};
  final Map<int, Timer> _recoverTimers = {};
  Timer? _pingTimer;

  // inbound notifications ko order me process karne ke liye
  Future<void> _inbound = Future.value();

  // channel/session set hone se pehle aayi notifications (15s se purani replay nahi hoti)
  final List<_EarlyNotif> _early = [];

  // outbound batching (Odoo 100ms batch)
  final List<List<dynamic>> _outbox = [];
  bool _flushScheduled = false;

  void _log(String m) => onLog?.call('[rtc] $m');

  // =====================================================================
  // HTTP (JSON-RPC, cookie auth)
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
      final res = await req.close().timeout(const Duration(seconds: 20));
      final bodyStr = await res.transform(utf8.decoder).join();
      final body = jsonDecode(bodyStr);
      // Odoo galti par bhi HTTP 200 deta hai; error body me hota hai
      if (body is Map && body['error'] != null) {
        final err = body['error'];
        final msg = (err is Map
            ? (err['data']?['message'] ?? err['message'])
            : err);
        throw Exception('RPC $route failed: $msg');
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

    // channels: [] => server partner ka private channel khud lagata hai
    _ws!.add(
      jsonEncode({
        'event_name': 'subscribe',
        'data': {'channels': [], 'last': _lastNotificationId},
      }),
    );

    // worker har 60s pe 0x00 byte bhejta hai
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
            (_) => _handleNotification(sender as int, content as String),
          );
        }
      } else if (type == 'discuss.channel.rtc.session/ended') {
        // V2: rtc_service.js: agar sessionId hamara hai to call khatam
        if (payload is Map && payload['sessionId'] is int) {
          handleSessionEnded(payload['sessionId'] as int);
        }
      }
    }
  }

  // =====================================================================
  // SHARED BUS (OdooBusService) se use karne ke liye
  // =====================================================================
  // Agar app me pehle se ek OdooBusService chal raha hai to connectBus() mat
  // chalao (do websocket = har notification do baar). Uske streams yahan jodo:
  //
  //   OdooBusService.instance.peerNotifications.listen((n) => rtc.handlePeerNotification(
  //       sender: n.senderSessionId, event: n.event,
  //       channelId: n.channelId, payload: n.payload));
  //   OdooBusService.instance.sessionEnded.listen(rtc.handleSessionEnded);

  Future<void> handlePeerNotification({
    required int sender,
    required String event,
    required int channelId,
    required Map<String, dynamic> payload,
  }) {
    final content = jsonEncode({
      'event': event,
      'channelId': channelId,
      'payload': payload,
    });
    _inbound = _inbound.then((_) => _handleNotification(sender, content));
    return _inbound;
  }

  void handleSessionEnded(int endedSessionId) {
    if (_selfId == null || endedSessionId != _selfId) return;
    _log('server ne hamara session end kiya');
    _teardown().then((_) => onCallEnded?.call());
  }

  // =====================================================================
  // CALL: join / attach / leave
  // =====================================================================

  Future<void> joinCall(int channelId, {int? invitationSessionId}) async {
    final data = await _rpc('/mail/rtc/channel/join_call', {
      'channel_id': channelId,
      'check_rtc_session_ids': invitationSessionId != null
          ? [invitationSessionId]
          : [],
      'camera': false,
    });
    await attachToCall(channelId, Map<String, dynamic>.from(data as Map));
  }

  /// join_call (ya aapki /api/chat/call/action accept) ke response ['data'] se.
  Future<void> attachToCall(int channelId, Map<String, dynamic> data) async {
    _channelId = channelId;
    final rtc = data['Rtc'] as Map;
    _selfId = rtc['selfSession'] as int;

    final ice = rtc['iceServers'];
    final parsedIce = <Map<String, dynamic>>[];
    bool hasValidTurn = false;
    if (ice is List) {
      for (final item in ice) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final rawUrls = m['urls'] ?? m['url'];
          final List<String> urlsList = [];
          if (rawUrls is String && rawUrls.trim().isNotEmpty) {
            urlsList.add(rawUrls.trim());
          } else if (rawUrls is List) {
            for (final u in rawUrls) {
              if (u != null && u.toString().trim().isNotEmpty) {
                urlsList.add(u.toString().trim());
              }
            }
          }
          if (urlsList.isEmpty) continue;
          final username = m['username']?.toString().trim();
          final credential = m['credential']?.toString().trim();
          final isTurn = urlsList.any(
            (u) => u.startsWith('turn:') || u.startsWith('turns:'),
          );
          if (isTurn) {
            final pointsToGoogle = urlsList.any(
              (u) => u.contains('stun.l.google.com'),
            );
            final hasCreds =
                username != null &&
                username.isNotEmpty &&
                credential != null &&
                credential.isNotEmpty;
            if (pointsToGoogle || !hasCreds) {
              if (pointsToGoogle) {
                parsedIce.add({
                  'urls': ['stun:stun.l.google.com:19302'],
                });
              }
              continue;
            }
            hasValidTurn = true;
          }
          parsedIce.add({
            'urls': urlsList,
            if (username != null && username.isNotEmpty) 'username': username,
            if (credential != null && credential.isNotEmpty)
              'credential': credential,
          });
        }
      }
    }
    if (parsedIce.isEmpty) {
      parsedIce.addAll(_defaultIceServers);
    }
    if (!hasValidTurn && CallConfig.turnFallback.isNotEmpty) {
      parsedIce.addAll(CallConfig.turnFallback);
    }
    _iceServers = parsedIce;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false,
    });

    await _serial(() async {
      // getUserMedia ke dauran koi offer aa chuka ho to us peer me mic abhi lagao
      for (final p in _peers.values.toList()) {
        await _attachLocalAudio(p);
      }

      // rtc_service.js call(): channel ke har DOOSRE session ke liye addPeer
      final others = _sessionIds(data, channelId, 'ADD')..remove(_selfId);
      _log('self=$_selfId, existing peers=$others');
      final seq = _nextSequence();
      for (final id in others) {
        if (_peers.containsKey(id)) continue; // us ne pehle offer bhej diya
        await _createPeer(id, sequence: seq);
      }
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ping());

    // join_call ke response se pehle bus par aayi notifications ab process karo
    final early = List<_EarlyNotif>.of(_early);
    _early.clear();
    final now = DateTime.now();
    for (final e in early) {
      if (now.difference(e.at) > const Duration(seconds: 15)) continue;
      _inbound = _inbound.then((_) => _handleNotification(e.sender, e.content));
    }
  }

  int? _asId(dynamic e) => e is int ? e : (e is Map ? e['id'] as int? : null);

  /// Store data se rtcSessions ke ["ADD"|"DELETE", [ids]] nikalta hai.
  Set<int> _sessionIds(Map<String, dynamic> data, int channelId, String op) {
    final ids = <int>{};
    final channels = data['discuss.channel'];
    if (channels is List) {
      for (final ch in channels) {
        if (ch is! Map || ch['id'] != channelId) continue;
        final ops = ch['rtcSessions'];
        if (ops is! List) continue;
        for (final o in ops) {
          if (o is List && o.length == 2 && o[0] == op && o[1] is List) {
            for (final e in (o[1] as List)) {
              final id = _asId(e);
              if (id != null) ids.add(id);
            }
          }
        }
      }
    }
    return ids;
  }

  /// rtc_service.js: har 30s ping() phir call()
  Future<void> _ping() async {
    final ch = _channelId;
    final self = _selfId;
    if (ch == null || self == null) return;
    try {
      final result = await _rpc('/discuss/channel/ping', {
        'channel_id': ch,
        'rtc_session_id': self,
        'check_rtc_session_ids': _peers.keys.toList(),
      });
      if (result is Map && _channelId == ch) {
        final data = Map<String, dynamic>.from(result);
        await _serial(() async {
          if (_channelId != ch) return;
          for (final id in _sessionIds(data, ch, 'DELETE')) {
            await _removePeer(id);
          }
          final added = _sessionIds(data, ch, 'ADD')..remove(self);
          final seq = _nextSequence();
          for (final id in added) {
            if (!_peers.containsKey(id)) await _createPeer(id, sequence: seq);
          }
        });
      }
    } catch (e) {
      _log('ping failed: $e');
    }
  }

  /// Incoming call reject karna. Odoo ka leave_call hi invitation cancel karta hai
  /// (discuss_channel_member.py: _rtc_leave_call ka else-branch).
  Future<void> declineCall(int channelId) async {
    await _rpc('/mail/rtc/channel/leave_call', {'channel_id': channelId});
  }

  Future<void> leaveCall() async {
    final ch = _channelId;
    if (ch == null) return;
    _enqueue('disconnect', null, _peers.keys.toList());
    await _flush();
    await _teardown();
    try {
      await _rpc('/mail/rtc/channel/leave_call', {'channel_id': ch});
    } catch (e) {
      _log('leave_call failed: $e');
    }
  }

  Future<void> _teardown() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final t in _recoverTimers.values) {
      t.cancel();
    }
    _recoverTimers.clear();
    for (final id in _peers.keys.toList()) {
      await _removePeer(id);
    }
    _outbox.clear();
    _early.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    _channelId = null;
    _selfId = null;
  }

  Future<void> dispose() async {
    await _teardown();
    disconnectBus();
  }

  Future<void> setMuted(bool muted) async {
    for (final t in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    _dcBroadcast('info', _info(muted));
    final self = _selfId;
    if (self == null) return;
    try {
      await _rpc('/mail/rtc/session/update_and_broadcast', {
        'session_id': self,
        'values': {'is_muted': muted},
      });
    } catch (e) {
      _log('update_and_broadcast failed: $e');
    }
  }

  Map<String, dynamic> _info(bool muted) => {
    'isSelfMuted': muted,
    'isRaisingHand': false,
    'isDeaf': false,
    'isTalking': false,
    'isCameraOn': false,
    'isScreenSharingOn': false,
  };

  // =====================================================================
  // PEER CREATION (_createPeer in peer_to_peer.js)
  // =====================================================================
  Future<_Peer> _createPeer(
    int id, {
    required int sequence,
    bool addTransceivers = true,
  }) async {
    await _removePeer(id);

    final pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });

    // V2: saare pc handlers PEHLE lagte hain, transceivers add hone se pehle.
    pc.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      if (_peers[id]?.pc != pc) return;
      _enqueue('ice-candidate', {'candidate': c.toMap()}, [id]);
    };

    pc.onRenegotiationNeeded = () async {
      final peer = _peers[id];
      if (peer == null || peer.pc != pc) return;
      if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable)
        return;
      if (peer.isBuildingOffer) return;
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
      if (local == null || _peers[id]?.pc != pc) return;
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
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _recoverTimers.remove(id)?.cancel();
        try {
          Helper.setSpeakerphoneOn(speakerOn);
        } catch (_) {}
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _scheduleRecover(id, 'PC $s');
      }
    };

    // V2: Odoo track bina stream ke bhejta hai (replaceTrack), isliye streams khali ho sakta hai
    pc.onTrack = (RTCTrackEvent e) async {
      _log('peer $id track: ${e.track.kind}');
      MediaStream stream;
      if (e.streams.isNotEmpty) {
        stream = e.streams.first;
      } else {
        stream =
            _remoteStreams[id] ?? await createLocalMediaStream('remote_$id');
        await stream.addTrack(e.track);
      }
      _remoteStreams[id] = stream;
      onRemoteStream?.call(id, stream);
    };

    // Odoo: negotiated data channel, id 1, label "notifications"
    final dc = await pc.createDataChannel(
      'notifications',
      RTCDataChannelInit()
        ..negotiated = true
        ..id = 1,
    );

    final peer = _Peer(id, pc, dc, id > (_selfId ?? 0), sequence);
    _peers[id] = peer;

    dc.onMessage = (RTCDataChannelMessage m) {
      _inbound = _inbound.then((_) => _handleNotification(id, m.text));
    };
    dc.onDataChannelState = (RTCDataChannelState s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        // browser "broadcast" aane tak hamara track/audio dikhata hi nahi
        _dcSend(peer, 'info', _info(false));
        _dcSend(peer, 'broadcast', {'sequence': peer.sequence});
      }
    };

    if (addTransceivers) {
      await _addMediaTransceivers(peer);
    }
    return peer;
  }

  /// Odoo ka fixed order: [0]=audio, [1]=camera, [2]=screen
  Future<void> _addMediaTransceivers(_Peer peer) async {
    final pc = peer.pc;
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
    _recoverTimers.remove(id)?.cancel();
    final peer = _peers.remove(id);
    final stream = _remoteStreams.remove(id);
    if (stream != null) {
      try {
        await stream.dispose();
      } catch (_) {}
    }
    if (peer == null) return;
    try {
      await peer.dc.close();
      await peer.pc.close();
    } catch (_) {}
  }

  /// V2: chhota recovery (peer_to_peer.js _recover). Connected nahi hua to
  /// 'disconnect' bhejke peer naye sequence ke saath dobara banta hai.
  void _scheduleRecover(int id, String reason) {
    if (_recoverTimers.containsKey(id)) return;
    _log('recover scheduled for $id: $reason');
    _recoverTimers[id] = Timer(const Duration(seconds: 6), () async {
      _recoverTimers.remove(id);
      await _serial(() async {
        final peer = _peers[id];
        if (peer == null || _channelId == null) return;
        final state = peer.pc.connectionState;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected)
          return;
        _log('recovering peer $id');
        _enqueue('disconnect', null, [id]);
        await _removePeer(id);
        await _createPeer(id, sequence: _nextSequence());
      });
    });
  }

  // =====================================================================
  // INBOUND (handleNotification in peer_to_peer.js)
  // =====================================================================
  Future<void> _handleNotification(int senderId, String content) async {
    if (_channelId == null || _selfId == null) {
      _early.add(_EarlyNotif(senderId, content, DateTime.now()));
      if (_early.length > 100) _early.removeAt(0);
      return;
    }
    try {
      final msg = jsonDecode(content) as Map<String, dynamic>;
      final event = msg['event'] as String;
      final channelId = msg['channelId'];
      final payload = msg['payload'];
      if (channelId != _channelId) return;
      _log('<- $event from $senderId');

      final peer = _peers[senderId];
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
              st == RTCSignalingState.RTCSignalingStateHaveRemoteOffer ||
              st == null) {
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
            peer.pendingCandidates.add(
              cand,
            ); // setRemoteDescription se pehle aaye
          } else {
            await peer.pc.addCandidate(cand);
          }
          break;
        case 'broadcast':
          peer!.ready = true;
          break;
        case 'info':
          break; // isTalking/isSelfMuted: UI chahiye to yahan se lo
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

    if (pc.signalingState ==
        RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
      return; // peer_to_peer.js bhi yahan return karta hai
    }

    final currentState = pc.signalingState;
    final hasLocalOffer =
        currentState == RTCSignalingState.RTCSignalingStateHaveLocalOffer;
    final collision = hasLocalOffer || peer.isBuildingOffer;
    if (collision) {
      if (peer.hasPriority) {
        // remote id bada hai: uska offer jeetega, apna rollback
        _log('offer collision with $senderId: rollback');
        if (hasLocalOffer) {
          try {
            await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
          } catch (e) {
            _log('rollback note: $e');
          }
        }
      } else {
        _log('offer collision with $senderId: ignoring (hamara priority)');
        return;
      }
    }

    await pc.setRemoteDescription(
      RTCSessionDescription(payload['sdp']['sdp'], payload['sdp']['type']),
    );
    await _flushCandidates(peer);

    // V2 (sabse zaroori): offer sirf data-channel ka ho to transceivers yahan add karo.
    // Answer ke baad negotiationneeded fire hoga aur hum media wala naya offer bhejenge,
    // bilkul Odoo ke browser ki tarah.
    if ((await pc.getTransceivers()).isEmpty) {
      await _addMediaTransceivers(peer);
    } else {
      await _attachLocalAudio(peer);
    }

    peer.isBuildingAnswer = true;
    try {
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
    } catch (e) {
      peer.isBuildingAnswer = false;
      _log('answer build failed: $e');
      _scheduleRecover(senderId, 'answer failed');
      return;
    }
    peer.isBuildingAnswer = false;

    final local = await pc.getLocalDescription();
    if (local == null || _peers[senderId]?.pc != pc) return;
    _enqueue(
      'answer',
      {
        'sdp': {'type': local.type, 'sdp': local.sdp},
      },
      [senderId],
    );
  }

  Future<void> _flushCandidates(_Peer peer) async {
    for (final c in List<RTCIceCandidate>.of(peer.pendingCandidates)) {
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
    final self = _selfId;
    if (self == null || targets.isEmpty) return;
    // peer_to_peer.js: [sender, targets, JSON.stringify({event, channelId, payload})]
    _outbox.add([
      self,
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
      _log('notify_call_members failed: $e'); // ab error body bhi yahan aayegi
    }
  }

  // =====================================================================
  // DATA CHANNEL helpers
  // =====================================================================
  void _dcSend(_Peer peer, String event, Map<String, dynamic> payload) {
    if (peer.dc.state != RTCDataChannelState.RTCDataChannelOpen) return;
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
