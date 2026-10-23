import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/call_provider.dart';
import '../../data/services/rtc_call_service.dart';
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

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.connected:
        return const Color(0xFF10B981); // Green
      case CallStatus.connecting:
      case CallStatus.ringing:
        return const Color(0xFFF59E0B); // Amber
      case CallStatus.failed:
      case CallStatus.ended:
        return const Color(0xFFEF4444); // Red
      case CallStatus.idle:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  String _getStatusText(CallStatus status, String iceState) {
    switch (status) {
      case CallStatus.connected:
        return 'Connected ($iceState)';
      case CallStatus.connecting:
        return 'Connecting ($iceState)...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.failed:
        return 'Connection Failed';
      case CallStatus.ended:
        return 'Call Ended';
      case CallStatus.idle:
        return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtcCallService = ref.watch(rtcCallServiceProvider);

    // Auto-pop when call is ended
    ref.listen<RtcCallService>(rtcCallServiceProvider, (prev, next) {
      if (next.status == CallStatus.ended || next.status == CallStatus.failed) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!context.mounted) return;
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          }
        });
      }
    });

    final passedName = widget.extra?['callee_name'] as String? ?? 'Odoo Discuss Admin';
    final channelId = widget.extra?['channel_id'] ?? rtcCallService.channelId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Live Diagnostics',
            icon: const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8)),
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
          // Ambient Glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Channel and Partner Info
                Text(
                  passedName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Channel ID #$channelId',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(rtcCallService.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(rtcCallService.status).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(rtcCallService.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusText(rtcCallService.status, rtcCallService.iceConnectionState),
                        style: TextStyle(
                          color: _getStatusColor(rtcCallService.status),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Timer
                Text(
                  _formatTimer(rtcCallService.callDuration),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),

                const Spacer(),

                // Animated Ripple Avatar
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildRippleCircle(_ripple1, 220),
                        _buildRippleCircle(_ripple2, 180),
                        _buildRippleCircle(_ripple3, 140),
                        // Central Avatar
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Call Controls: Mute, Speaker, Hangup, Debug Logs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      _buildControlButton(
                        icon: rtcCallService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: rtcCallService.isMuted ? 'Unmute' : 'Mute',
                        isActive: rtcCallService.isMuted,
                        activeColor: const Color(0xFFEF4444),
                        onPressed: () => rtcCallService.toggleMute(),
                      ),

                      // Speaker Toggle Button
                      _buildControlButton(
                        icon: rtcCallService.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: rtcCallService.isSpeakerOn ? 'Speaker' : 'Earpiece',
                        isActive: rtcCallService.isSpeakerOn,
                        activeColor: const Color(0xFF38BDF8),
                        onPressed: () => rtcCallService.toggleSpeaker(),
                      ),

                      // Debug Logs Button
                      _buildControlButton(
                        icon: Icons.receipt_long_rounded,
                        label: 'Logs',
                        isActive: false,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RtcDebugLogScreen()),
                          );
                        },
                      ),

                      // Hang Up Button (Red)
                      GestureDetector(
                        onTap: () => rtcCallService.hangUp(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
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
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'End',
                              style: TextStyle(
                                color: Color(0xFFF87171),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
              color: const Color(0xFF38BDF8).withValues(alpha: (1.0 - animation.value).clamp(0.0, 1.0) * 0.35),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor.withValues(alpha: 0.2) : const Color(0xFF334155),
              border: Border.all(
                color: isActive ? activeColor : const Color(0xFF475569),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
