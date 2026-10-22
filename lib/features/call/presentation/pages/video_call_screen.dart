import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';
import '../widgets/call_controls_widget.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;
  const VideoCallScreen({super.key, this.extra});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  // Draggable PiP coordinates
  double _pipX = 20;
  double _pipY = 90;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
      if (prev != null && prev.status != CallState.idle) {
        if (next.status == CallState.ended ||
            next.status == CallState.rejected ||
            next.status == CallState.cancelled ||
            next.status == CallState.missed) {
          if (mounted && context.canPop()) {
            context.pop();
          }
        }
      }
    });

    final passedName = widget.extra?['callee_name'] as String?;
    final partnerName = callState.isIncoming
        ? (call?.caller.name ?? 'Caller')
        : (call?.callee.name ?? passedName ?? 'Connecting...');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fullscreen Remote Video Stream or Waiting Screen
          Positioned.fill(
            child: callState.status == CallState.connected
                ? RTCVideoView(
                    webrtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 1.2,
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF0F172A),
                          Color(0xFF030712),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.buttonGradient,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.purple1.withValues(alpha: 0.45),
                                    blurRadius: 35,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            partnerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  callState.status == CallState.ringing
                                      ? (callState.isIncoming ? 'Incoming Video Call...' : 'Ringing...')
                                      : 'Connecting WebRTC Video...',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Top Header Bar (Translucent Glass with Back, Name, Timer, Quality)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                            onPressed: () {
                              if (context.canPop()) context.pop();
                            },
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: AppColors.purple1,
                            child: Text(
                              partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  partnerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (callState.status == CallState.connected) ...[
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Colors.greenAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      callState.status == CallState.connected
                                          ? '${_formatTimer(callState.durationSeconds)} • HD WebRTC'
                                          : (callState.status == CallState.ringing ? 'Ringing...' : 'Connecting...'),
                                      style: TextStyle(
                                        color: callState.status == CallState.connected
                                            ? Colors.greenAccent
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded,
                                color: Colors.white70, size: 22),
                            tooltip: 'Flip Camera',
                            onPressed: callManager.switchCamera,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Draggable PiP (Picture-in-Picture) Local Video View
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
                width: 115,
                height: 165,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: callState.isVideoOff
                          ? Container(
                              color: const Color(0xFF0F172A),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam_off_rounded,
                                        color: Colors.white54, size: 28),
                                    SizedBox(height: 4),
                                    Text(
                                      'Camera Off',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RTCVideoView(
                              webrtc.localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                    ),
                    // Quick camera flip button on PiP
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: callManager.switchCamera,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.flip_camera_ios,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Controls Deck Floating in Glass
          Positioned(
            bottom: 30,
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
                  if (mounted && context.canPop()) {
                    context.pop();
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
