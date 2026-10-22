import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';
import '../widgets/call_controls_widget.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  const AudioCallScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callManagerProvider);
    final callManager = ref.read(callManagerProvider.notifier);
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

    final partnerName = callState.isIncoming
        ? (call?.caller.name ?? 'Caller')
        : (call?.callee.name ?? 'Calling...');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // 1. Ambient Background Glows
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple1.withValues(alpha: 0.25),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.18),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // 2. Safe Area Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70, size: 30),
                        tooltip: 'Minimize Call',
                        onPressed: () {
                          if (context.canPop()) context.pop();
                        },
                      ),
                      // Encryption & Protocol Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 13, color: Colors.greenAccent),
                            SizedBox(width: 6),
                            Text(
                              'End-to-End WebRTC',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Balance spacing
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Center Pulsing Avatar with Multi-layer Sonar Ripple
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple 1
                        AnimatedBuilder(
                          animation: _ripple1,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _ripple1.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.purple1.withValues(
                                      alpha: (1.0 - _rippleController.value) * 0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Ripple 2
                        AnimatedBuilder(
                          animation: _ripple2,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _ripple2.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.cyanAccent.withValues(
                                      alpha: (1.0 - _rippleController.value) * 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Ripple 3
                        AnimatedBuilder(
                          animation: _ripple3,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _ripple3.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.purple1.withValues(
                                    alpha: (1.0 - _rippleController.value) * 0.12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Avatar Card
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                                Color(0xFFD946EF),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 62,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Partner Name
                Text(
                  partnerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Call Status / Duration Indicator
                if (callState.status == CallState.connected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimer(callState.durationSeconds),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.greenAccent,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• HD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      callState.status == CallState.ringing
                          ? (callState.isIncoming ? 'Incoming Audio Call...' : 'Ringing...')
                          : (callState.status == CallState.connecting
                              ? 'Connecting WebRTC...'
                              : 'Call Ended'),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const Spacer(flex: 3),

                // Modern Bottom Floating Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: CallControlsWidget(
                    isVideo: false,
                    isMuted: callState.isMuted,
                    isSpeakerOn: callState.isSpeakerOn,
                    onToggleMute: callManager.toggleMute,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
