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

class _AudioCallScreenState extends ConsumerState<AudioCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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

    final partnerName = callState.isIncoming ? (call?.caller.name ?? 'Caller') : (call?.callee.name ?? 'Calling...');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Gradient Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Pulsing Avatar
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple1.withValues(alpha: 0.35),
                            blurRadius: 35,
                            spreadRadius: 8,
                          ),
                        ],
                        gradient: AppColors.buttonGradient,
                      ),
                      child: Center(
                        child: Text(
                          partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Partner Name
                  Text(
                    partnerName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status / Duration
                  if (callState.status == CallState.connected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _formatTimer(callState.durationSeconds),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                  else
                    Text(
                      callState.status == CallState.ringing
                          ? (callState.isIncoming ? 'Incoming Audio Call...' : 'Ringing...')
                          : (callState.status == CallState.connecting ? 'Connecting...' : 'Call Ended'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const Spacer(flex: 3),

                  // Call Controls Bar
                  CallControlsWidget(
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
