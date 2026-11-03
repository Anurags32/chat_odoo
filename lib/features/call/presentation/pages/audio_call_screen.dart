import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';
import 'rtc_debug_log_screen.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;
  const AudioCallScreen({super.key, this.extra});

  @override
  ConsumerState<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends ConsumerState<AudioCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _ripple1;
  late Animation<double> _ripple2;
  late Animation<double> _ripple3;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _ripple1 = Tween<double>(begin: 0.8, end: 1.45).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _ripple2 = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _ripple3 = Tween<double>(begin: 0.8, end: 1.15).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
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
                    'End Audio Call?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leaving this screen will end the ongoing call.',
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

  Color _getStatusColor(CallState status) {
    switch (status) {
      case CallState.connected:
        return const Color(0xFF10B981); // Emerald Green
      case CallState.connecting:
        return const Color(0xFF38BDF8); // Sky Blue
      case CallState.ringing:
        return const Color(0xFFF59E0B); // Amber
      case CallState.failed:
      case CallState.ended:
      case CallState.rejected:
      case CallState.cancelled:
      case CallState.missed:
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String _getStatusText(CallState status, String iceState) {
    switch (status) {
      case CallState.connected:
        return 'Connected ($iceState)';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.failed:
        return 'Connection Failed';
      case CallState.ended:
        return 'Call Ended';
      case CallState.rejected:
        return 'Call Declined';
      case CallState.cancelled:
        return 'Call Cancelled';
      case CallState.missed:
        return 'Call Missed';
      default:
        return 'Calling...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callManagerProvider);
    final callManager = ref.read(callManagerProvider.notifier);
    final rtcCallService = ref.watch(rtcCallServiceProvider);

    // Guaranteed Single Exit: Only trigger pop when transitioning from active -> terminated
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

    final partnerName =
        callState.partnerName ??
        widget.extra?['callee_name'] as String? ??
        (callState.isIncoming
            ? (callState.activeCall?.caller.name ?? 'Odoo User')
            : (callState.activeCall?.callee.name ?? 'Odoo User'));
    final channelId =
        callState.channelId ??
        widget.extra?['channel_id'] ??
        rtcCallService.channelId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white70,
            ),
            onPressed: _handleBackPress,
          ),
          actions: [
            IconButton(
              tooltip: 'Live Diagnostics',
              icon: const Icon(
                Icons.terminal_rounded,
                color: Color(0xFF38BDF8),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RtcDebugLogScreen()),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Ambient Neon Glow Highlights
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Partner Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      partnerName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channelId > 0 ? 'Channel #$channelId' : 'Direct Call',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        callState.status,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(
                          callState.status,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(callState.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(
                            callState.status,
                            rtcCallService.iceConnectionState,
                          ),
                          style: TextStyle(
                            color: _getStatusColor(callState.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Duration Timer
                  Text(
                    _formatTimer(callState.durationSeconds),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),

                  const Spacer(),

                  // Animated Ripple Soundwave Avatar
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (callState.status == CallState.connected ||
                              callState.status == CallState.ringing ||
                              callState.status == CallState.connecting) ...[
                            _buildRippleCircle(_ripple1, 230),
                            _buildRippleCircle(_ripple2, 190),
                            _buildRippleCircle(_ripple3, 160),
                          ],
                          Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                partnerName.isNotEmpty
                                    ? partnerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Controls Bar
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 34,
                      left: 24,
                      right: 24,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(44),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(44),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Mute Toggle
                              _buildControlButton(
                                icon: callState.isMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                label: callState.isMuted ? 'Unmute' : 'Mute',
                                isActive: callState.isMuted,
                                activeColor: const Color(0xFFEF4444),
                                onPressed: callManager.toggleMute,
                              ),

                              // Speaker Toggle
                              _buildControlButton(
                                icon: callState.isSpeakerOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded,
                                label: callState.isSpeakerOn
                                    ? 'Speaker'
                                    : 'Earpiece',
                                isActive: callState.isSpeakerOn,
                                activeColor: const Color(0xFF38BDF8),
                                onPressed: callManager.toggleSpeaker,
                              ),

                              // Switch to Video
                              _buildControlButton(
                                icon: Icons.videocam_rounded,
                                label: 'Video',
                                isActive: false,
                                activeColor: const Color(0xFF10B981),
                                onPressed: () async {
                                  final router = GoRouter.of(context);
                                  await callManager.toggleVideo();
                                  if (mounted) {
                                    router.pushReplacement(
                                      '/video-call',
                                      extra: widget.extra,
                                    );
                                  }
                                },
                              ),

                              // Live Diagnostics
                              _buildControlButton(
                                icon: Icons.terminal_rounded,
                                label: 'Logs',
                                isActive: false,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RtcDebugLogScreen(),
                                    ),
                                  );
                                },
                              ),

                              // Hang Up Button (Red)
                              GestureDetector(
                                onTap: () async {
                                  if (_isExiting) return;
                                  _isExiting = true;
                                  await callManager.endCall();
                                  if (mounted) _safeExit();
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFDC2626),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x66DC2626),
                                            blurRadius: 16,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.call_end_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'End',
                                      style: TextStyle(
                                        color: Color(0xFFF87171),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRippleCircle(Animation<double> animation, double size) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: size * animation.value,
          height: size * animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(
                alpha: (1.0 - animation.value).clamp(0.0, 1.0) * 0.35,
              ),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    Color activeColor = const Color(0xFF38BDF8),
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? activeColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
