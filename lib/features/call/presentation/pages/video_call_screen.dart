import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';
import '../../data/services/rtc_call_service.dart';
import '../widgets/call_controls_widget.dart';
import 'rtc_debug_log_screen.dart';

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
  bool _isExiting = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rtcCallServiceProvider).initRenderers();
    });

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

  void _safeExit() {
    if (_isExiting || !mounted) return;
    _isExiting = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _handleBackPress() async {
    final callState = ref.read(callManagerProvider);
    if (callState.status == CallState.connected ||
        callState.status == CallState.connecting) {
      final shouldEnd = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF1E293B).withValues(alpha: 0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.call_end_rounded,
                    color: Colors.redAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'End Video Call?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leaving this screen will end the ongoing video call.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Stay',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'End Call',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (shouldEnd == true && mounted) {
        await ref.read(callManagerProvider.notifier).endCall();
        _safeExit();
      }
    } else {
      _safeExit();
    }
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
    final rtcCallService = ref.watch(rtcCallServiceProvider);
    final call = callState.activeCall;

    // Single Guarded Listener: Pop screen only when active call transitions to terminated
    ref.listen<CallStateData>(callManagerProvider, (prev, next) {
      if (prev != null &&
          (prev.status == CallState.connected ||
              prev.status == CallState.connecting ||
              prev.status == CallState.ringing)) {
        if (next.status == CallState.ended ||
            next.status == CallState.failed ||
            next.status == CallState.rejected ||
            next.status == CallState.cancelled) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) _safeExit();
          });
        }
      }
    });

    final passedName = widget.extra?['callee_name'] as String?;
    final partnerName =
        callState.partnerName ??
        (callState.isIncoming
            ? (call?.caller.name ?? 'Caller')
            : (call?.callee.name ?? passedName ?? 'Connecting...'));

    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Fullscreen Remote Video Stream, Mesh Grid or Waiting Screen
            Positioned.fill(
              child: _buildRemoteVideoContent(
                rtcCallService,
                callState,
                partnerName,
              ),
            ),

            // 2. Top Header Bar (Translucent Glass with Back, Name, Timer, Quality, Diagnostics)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _handleBackPress,
                            ),
                            const SizedBox(width: 6),
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: AppColors.purple1,
                              child: Text(
                                partnerName.isNotEmpty
                                    ? partnerName[0].toUpperCase()
                                    : '?',
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
                                      if (callState.status ==
                                          CallState.connected) ...[
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
                                            : (callState.status ==
                                                      CallState.ringing
                                                  ? 'Ringing...'
                                                  : 'Connecting...'),
                                        style: TextStyle(
                                          color:
                                              callState.status ==
                                                  CallState.connected
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
                              icon: const Icon(
                                Icons.terminal_rounded,
                                color: Color(0xFF38BDF8),
                                size: 22,
                              ),
                              tooltip: 'Live Diagnostics',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RtcDebugLogScreen(),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.flip_camera_ios_rounded,
                                color: Colors.white70,
                                size: 22,
                              ),
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

            // 3. Draggable PiP (Picture-in-Picture) Local Video View with Bound Clamping
            Positioned(
              left: _pipX.clamp(10.0, screenSize.width - 130.0),
              top: _pipY.clamp(80.0, screenSize.height - 260.0),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipX = (_pipX + details.delta.dx).clamp(
                      10.0,
                      screenSize.width - 130.0,
                    );
                    _pipY = (_pipY + details.delta.dy).clamp(
                      80.0,
                      screenSize.height - 260.0,
                    );
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
                                      Icon(
                                        Icons.videocam_off_rounded,
                                        color: Colors.white54,
                                        size: 28,
                                      ),
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
                                rtcCallService.localRenderer,
                                mirror: true,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
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
                              child: Icon(
                                Icons.flip_camera_ios,
                                size: 14,
                                color: Colors.white,
                              ),
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
                  isScreenSharing: rtcCallService.isScreenSharing,
                  onToggleMute: callManager.toggleMute,
                  onToggleVideo: callManager.toggleVideo,
                  onSwitchCamera: callManager.switchCamera,
                  onToggleScreenShare: rtcCallService.toggleScreenShare,
                  onToggleSpeaker: callManager.toggleSpeaker,
                  onEndCall: () async {
                    if (_isExiting) return;
                    _isExiting = true;
                    if (callState.isIncoming &&
                        callState.status == CallState.ringing) {
                      await callManager.rejectCall();
                    } else if (!callState.isIncoming &&
                        callState.status == CallState.ringing) {
                      await callManager.cancelCall();
                    } else {
                      await callManager.endCall();
                    }
                    if (mounted) _safeExit();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideoContent(
    RtcCallService rtcCallService,
    CallStateData callState,
    String partnerName,
  ) {
    if (callState.status != CallState.connected) {
      return _buildWaitingPlaceholder(partnerName, callState);
    }

    final peers = rtcCallService.peerList;
    if (peers.isEmpty) {
      return _buildWaitingPlaceholder(partnerName, callState);
    }

    if (peers.length == 1) {
      final peer = peers.first;
      if (peer.isCameraActive) {
        return RTCVideoView(
          peer.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      } else {
        return _buildAudioOnlyPeer(peer, partnerName);
      }
    }

    // Mesh Grid for 2 or more remote peers
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.only(top: 80, bottom: 120, left: 10, right: 10),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: peers.length <= 4 ? 2 : 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
        ),
        itemCount: peers.length,
        itemBuilder: (context, index) {
          final peer = peers[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFF1E293B),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: peer.isCameraActive
                        ? RTCVideoView(
                            peer.remoteRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        : _buildAudioOnlyPeer(
                            peer,
                            'Participant #${peer.remoteSessionId}',
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (peer.isMuted) ...[
                            const Icon(
                              Icons.mic_off_rounded,
                              size: 12,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            'Session #${peer.remoteSessionId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioOnlyPeer(dynamic peer, String name) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.purple1,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Camera Off (Audio Only)',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingPlaceholder(String partnerName, CallStateData callState) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF030712)],
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    callState.status == CallState.ringing
                        ? (callState.isIncoming
                              ? 'Incoming Video Call...'
                              : 'Ringing...')
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
    );
  }
}
