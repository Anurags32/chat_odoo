import 'dart:ui';
import 'package:flutter/material.dart';

class CallControlsWidget extends StatelessWidget {
  final bool isVideo;
  final bool isMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final bool isScreenSharing;
  final VoidCallback onToggleMute;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onToggleScreenShare;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const CallControlsWidget({
    super.key,
    required this.isVideo,
    required this.isMuted,
    this.isVideoOff = false,
    required this.isSpeakerOn,
    this.isScreenSharing = false,
    required this.onToggleMute,
    this.onToggleVideo,
    this.onSwitchCamera,
    this.onToggleScreenShare,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(44),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mute Mic Button
              _ControlButton(
                icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                isActive: isMuted,
                activeColor: Colors.redAccent,
                activeIconColor: Colors.white,
                onPressed: onToggleMute,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              ),
              const SizedBox(width: 14),

              // Speakerphone Button
              _ControlButton(
                icon: isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                isActive: isSpeakerOn,
                activeColor: Colors.cyanAccent.shade700,
                activeIconColor: Colors.white,
                onPressed: onToggleSpeaker,
                tooltip: isSpeakerOn ? 'Speaker ON' : 'Earpiece',
              ),

              if (isVideo) ...[
                const SizedBox(width: 14),
                // Camera On/Off Toggle
                _ControlButton(
                  icon: isVideoOff
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                  isActive: isVideoOff,
                  activeColor: Colors.amber.shade700,
                  activeIconColor: Colors.white,
                  onPressed: onToggleVideo,
                  tooltip: isVideoOff ? 'Turn Video ON' : 'Turn Video OFF',
                ),
                const SizedBox(width: 14),
                // Switch Camera (Front/Back)
                _ControlButton(
                  icon: Icons.flip_camera_ios_rounded,
                  isActive: false,
                  onPressed: onSwitchCamera,
                  tooltip: 'Flip Camera',
                ),
                if (onToggleScreenShare != null) ...[
                  const SizedBox(width: 14),
                  // Screen Share Button
                  _ControlButton(
                    icon: isScreenSharing
                        ? Icons.stop_screen_share_rounded
                        : Icons.screen_share_rounded,
                    isActive: isScreenSharing,
                    activeColor: Colors.deepPurpleAccent,
                    activeIconColor: Colors.white,
                    onPressed: onToggleScreenShare,
                    tooltip: isScreenSharing ? 'Stop Screen Share' : 'Share Screen',
                  ),
                ],
              ],

              const SizedBox(width: 18),

              // End Call Glowing Button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onEndCall,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF3B30),
                            Color(0xFFCC0000),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final Color? activeIconColor;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    this.activeColor,
    this.activeIconColor,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? (activeColor ?? Colors.white.withValues(alpha: 0.9))
                  : Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: isActive && activeColor != null
                  ? [
                      BoxShadow(
                        color: activeColor!.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive
                  ? (activeIconColor ?? Colors.black87)
                  : Colors.white,
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}
