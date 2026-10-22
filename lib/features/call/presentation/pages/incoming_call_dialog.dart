import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../data/providers/call_provider.dart';

class IncomingCallDialog extends ConsumerWidget {
  const IncomingCallDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callManagerProvider);
    final callManager = ref.read(callManagerProvider.notifier);
    final call = callState.activeCall;

    if (!callState.isIncoming || callState.status != CallState.ringing || call == null) {
      return const SizedBox.shrink();
    }

    final callerName = call.caller.name;
    final isVideo = call.callType == CallType.video;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Ambient blurred backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),

          // Central Incoming Call Modal
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caller Avatar with Glowing Border
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.buttonGradient,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple1.withValues(alpha: 0.5),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Caller Name
                  Text(
                    callerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Call Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          size: 16,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons: Decline & Accept
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Material(
                              color: const Color(0xFFFF3B30),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => callManager.rejectCall(),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Icon(Icons.call_end_rounded,
                                      color: Colors.white, size: 30),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Accept Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Material(
                              color: const Color(0xFF34C759),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () async {
                                  final success = await callManager.acceptCall();
                                  if (success && context.mounted) {
                                    if (isVideo) {
                                      context.push('/video-call');
                                    } else {
                                      context.push('/audio-call');
                                    }
                                  }
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Icon(
                                    isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.call_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
