import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';
import '../widgets/call_controls_widget.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // Draggable PiP coordinates
  double _pipX = 20;
  double _pipY = 50;

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callManagerProvider);
    final callManager = ref.read(callManagerProvider.notifier);
    final webrtc = ref.read(webrtcServiceProvider);
    final call = callState.activeCall;

    // Pop screen when call ends or is cancelled/rejected
    ref.listen<CallStateData>(callManagerProvider, (prev, next) {
      if (next.status == CallState.ended ||
          next.status == CallState.rejected ||
          next.status == CallState.cancelled ||
          next.status == CallState.missed ||
          next.status == CallState.idle) {
        if (mounted && context.canPop()) {
          context.pop();
        }
      }
    });

    final partnerName = callState.isIncoming ? (call?.caller.name ?? 'Caller') : (call?.callee.name ?? 'Connecting...');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fullscreen Remote Video View
          Positioned.fill(
            child: callState.status == CallState.connected
                ? RTCVideoView(
                    webrtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 24),
                          Text(
                            callState.status == CallState.ringing
                                ? (callState.isIncoming ? 'Incoming Video Call...' : 'Ringing...')
                                : 'Connecting Video Stream...',
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Top Header Bar (Name, State, Timer)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    child: Text(
                      partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        partnerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        callState.status == CallState.connected
                            ? _formatTimer(callState.durationSeconds)
                            : (callState.status == CallState.ringing ? 'Ringing' : 'Connecting...'),
                        style: TextStyle(
                          color: callState.status == CallState.connected ? Colors.greenAccent : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Draggable Local Video View (Picture-in-Picture)
          Positioned(
            left: _pipX,
            top: _pipY,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _pipX += details.delta.dx;
                  _pipY += details.delta.dy;
                });
              },
              child: Container(
                width: 110,
                height: 155,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: callState.isVideoOff
                    ? const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white54, size: 30),
                      )
                    : RTCVideoView(
                        webrtc.localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              ),
            ),
          ),

          // 4. Bottom Call Controls Bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CallControlsWidget(
                isVideo: true,
                isMuted: callState.isMuted,
                isVideoOff: callState.isVideoOff,
                isSpeakerOn: callState.isSpeakerOn,
                onToggleMute: callManager.toggleMute,
                onToggleVideo: callManager.toggleVideo,
                onSwitchCamera: callManager.switchCamera,
                onToggleSpeaker: callManager.toggleSpeaker,
                onEndCall: () {
                  if (callState.isIncoming && callState.status == CallState.ringing) {
                    callManager.rejectCall();
                  } else if (!callState.isIncoming && callState.status == CallState.ringing) {
                    callManager.cancelCall();
                  } else {
                    callManager.endCall();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
