import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/rtc_logger.dart';

/// Represents a remote WebRTC peer session inside the mesh call
class RtcPeerSession {
  final int remoteSessionId;
  final int selfSessionId;
  final RTCPeerConnection connection;
  final bool hasPriority; // remoteSessionId > selfSessionId (Polite Peer negotiation)

  RTCDataChannel? dataChannel;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool rendererInitialized = false;

  MediaStream? remoteStream;
  MediaStreamTrack? remoteAudioTrack;
  MediaStreamTrack? remoteVideoTrack;
  MediaStreamTrack? remoteScreenTrack;

  bool isCameraActive = false;
  bool isAudioActive = true;
  bool isScreenSharingActive = false;
  bool isTalking = false;
  bool isRemoteMuted = false;

  bool get isMuted => isRemoteMuted;
  bool get isCameraOn => isCameraActive;

  String iceConnectionState = 'new';
  String peerConnectionState = 'new';
  String iceGatheringState = 'new';

  int sequence = 0;
  bool isBuildingOffer = false;
  bool isBuildingAnswer = false;
  bool remoteDescriptionSet = false;
  final List<RTCIceCandidate> queuedCandidates = [];

  // Stats tracking
  int bytesSentAudio = 0;
  int bytesReceivedAudio = 0;
  int bytesSentVideo = 0;
  int bytesReceivedVideo = 0;
  String? selectedCandidatePair;

  RtcPeerSession({
    required this.remoteSessionId,
    required this.selfSessionId,
    required this.connection,
    required this.hasPriority,
  });

  Future<void> initRenderer() async {
    if (rendererInitialized) return;
    try {
      await remoteRenderer.initialize();
      rendererInitialized = true;
      RtcLogger.instance.log('Remote renderer initialized for peer $remoteSessionId', tag: 'PEER');
    } catch (e) {
      RtcLogger.instance.log('Failed to init renderer for peer $remoteSessionId: $e', tag: 'PEER');
    }
  }

  void queueCandidate(RTCIceCandidate candidate) {
    queuedCandidates.add(candidate);
    RtcLogger.instance.log(
      'Queued candidate for peer $remoteSessionId (total queued: ${queuedCandidates.length})',
      tag: 'ICE-QUEUE',
    );
  }

  Future<void> flushQueuedCandidates() async {
    if (queuedCandidates.isEmpty) return;
    RtcLogger.instance.log(
      'Flushing ${queuedCandidates.length} queued candidates for peer $remoteSessionId',
      tag: 'ICE-QUEUE',
    );
    for (final candidate in List<RTCIceCandidate>.from(queuedCandidates)) {
      try {
        await connection.addCandidate(candidate);
      } catch (e) {
        RtcLogger.instance.log('Error adding queued candidate: $e', tag: 'ICE-ERROR');
      }
    }
    queuedCandidates.clear();
  }

  void updateFromInfo(Map<String, dynamic> info) {
    if (info.containsKey('isCameraOn')) {
      isCameraActive = info['isCameraOn'] == true;
    }
    if (info.containsKey('isSelfMuted')) {
      isRemoteMuted = info['isSelfMuted'] == true;
    }
    if (info.containsKey('isTalking')) {
      isTalking = info['isTalking'] == true;
    }
    if (info.containsKey('isScreenSharingOn')) {
      isScreenSharingActive = info['isScreenSharingOn'] == true;
    }
  }

  Future<void> dispose() async {
    try {
      await dataChannel?.close();
    } catch (_) {}
    dataChannel = null;

    remoteRenderer.srcObject = null;
    if (rendererInitialized) {
      try {
        await remoteRenderer.dispose();
      } catch (_) {}
      rendererInitialized = false;
    }

    if (remoteStream != null) {
      for (final t in remoteStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        await remoteStream!.dispose();
      } catch (_) {}
      remoteStream = null;
    }

    try {
      await connection.close();
      await connection.dispose();
    } catch (_) {}

    queuedCandidates.clear();
    RtcLogger.instance.log('Disposed peer session $remoteSessionId cleanly.', tag: 'PEER');
  }
}
