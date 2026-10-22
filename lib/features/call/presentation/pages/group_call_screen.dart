import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';

class GroupCallParticipant {
  final int id;
  final String name;
  final bool isSpeaking;
  final bool isMuted;
  final bool isVideoOff;
  final RTCVideoRenderer? renderer;

  GroupCallParticipant({
    required this.id,
    required this.name,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isVideoOff = false,
    this.renderer,
  });
}

class GroupCallScreen extends ConsumerStatefulWidget {
  final String channelName;
  final CallType callType;
  final List<String> initialMembers;

  const GroupCallScreen({
    super.key,
    required this.channelName,
    this.callType = CallType.video,
    this.initialMembers = const [],
  });

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen> {
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _isVideoOff = widget.callType == CallType.audio;
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _callDurationSeconds++;
      });
      return true;
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleMic() {
    setState(() => _isMicMuted = !_isMicMuted);
    ref.read(webrtcServiceProvider).toggleAudioMute();
  }

  void _toggleVideo() {
    setState(() => _isVideoOff = !_isVideoOff);
    ref.read(webrtcServiceProvider).toggleVideo();
  }

  void _switchCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    ref.read(webrtcServiceProvider).switchCamera();
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    ref.read(webrtcServiceProvider).toggleSpeaker();
  }

  void _endCall() {
    ref.read(webrtcServiceProvider).endCall();
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final webrtc = ref.read(webrtcServiceProvider);

    // Mock representation of connected group members for the grid layout
    final participants = [
      GroupCallParticipant(
        id: 0,
        name: 'You',
        isMuted: _isMicMuted,
        isVideoOff: _isVideoOff,
        renderer: webrtc.localRenderer,
      ),
      if (widget.initialMembers.isNotEmpty)
        ...widget.initialMembers.map(
          (m) => GroupCallParticipant(
            id: m.hashCode,
            name: m,
            isSpeaking: false,
            isMuted: false,
            isVideoOff: widget.callType == CallType.audio,
            renderer: webrtc.remoteRenderer,
          ),
        )
      else ...[
        GroupCallParticipant(
          id: 1,
          name: 'Sarah Connor',
          isSpeaking: true,
          isVideoOff: widget.callType == CallType.audio,
          renderer: webrtc.remoteRenderer,
        ),
        GroupCallParticipant(
          id: 2,
          name: 'Alex Miller',
          isMuted: true,
          isVideoOff: true,
        ),
        GroupCallParticipant(
          id: 3,
          name: 'David Chen',
          isSpeaking: false,
          isVideoOff: true,
        ),
      ]
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Stack(
          children: [
            // Top Bar with Channel Name and Duration
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    color: Colors.white.withValues(alpha: 0.08),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.group_rounded,
                                color: AppColors.accentTeal,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.channelName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${participants.length} Active Participants',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatDuration(_callDurationSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Adaptive Participant Video Grid Layout
            Positioned.fill(
              top: 80,
              bottom: 110,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildAdaptiveGrid(participants),
              ),
            ),

            // Bottom Call Controls
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _buildControlsBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveGrid(List<GroupCallParticipant> list) {
    if (list.length <= 2) {
      return Column(
        children: list.map((p) => Expanded(child: _buildParticipantTile(p))).toList(),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        return _buildParticipantTile(list[index]);
      },
    );
  }

  Widget _buildParticipantTile(GroupCallParticipant p) {
    final hasActiveVideo = !p.isVideoOff && p.renderer != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: p.isSpeaking
              ? AppColors.online
              : Colors.white.withValues(alpha: 0.12),
          width: p.isSpeaking ? 2.5 : 1,
        ),
        boxShadow: p.isSpeaking
            ? [
                BoxShadow(
                  color: AppColors.online.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video View or Avatar Placeholder
          if (hasActiveVideo)
            Positioned.fill(
              child: RTCVideoView(
                p.renderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: p.name == 'You' && _isFrontCamera,
              ),
            )
          else
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // Name and Status Tag
          Positioned(
            left: 8,
            bottom: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (p.isMuted) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.mic_off_rounded,
                          size: 13,
                          color: Colors.redAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mic Toggle
              _buildControlCircle(
                icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                isActive: !_isMicMuted,
                onTap: _toggleMic,
              ),

              // Video Toggle
              _buildControlCircle(
                icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                isActive: !_isVideoOff,
                onTap: _toggleVideo,
              ),

              // Switch Camera
              if (!_isVideoOff)
                _buildControlCircle(
                  icon: Icons.flip_camera_ios_rounded,
                  isActive: true,
                  onTap: _switchCamera,
                ),

              // Speaker Toggle
              _buildControlCircle(
                icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                isActive: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),

              // End Call Button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error,
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCircle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.redAccent.withValues(alpha: 0.25),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.redAccent,
          size: 22,
        ),
      ),
    );
  }
}
