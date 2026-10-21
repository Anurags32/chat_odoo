import 'package:flutter/material.dart';

class CallControlsWidget extends StatelessWidget {
  final bool isVideo;
  final bool isMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const CallControlsWidget({
    super.key,
    required this.isVideo,
    required this.isMuted,
    this.isVideoOff = false,
    required this.isSpeakerOn,
    required this.onToggleMute,
    this.onToggleVideo,
    this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Toggle
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            isActive: isMuted,
            onPressed: onToggleMute,
            tooltip: isMuted ? 'Unmute' : 'Mute',
          ),
          const SizedBox(width: 16),

          // Speaker Toggle
          _ControlButton(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            isActive: isSpeakerOn,
            onPressed: onToggleSpeaker,
            tooltip: isSpeakerOn ? 'Speaker On' : 'Earpiece',
          ),

          if (isVideo) ...[
            const SizedBox(width: 16),
            // Video Camera Toggle
            _ControlButton(
              icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
              isActive: isVideoOff,
              onPressed: onToggleVideo,
              tooltip: isVideoOff ? 'Turn Video On' : 'Turn Video Off',
            ),
            const SizedBox(width: 16),
            // Switch Camera Front / Back
            _ControlButton(
              icon: Icons.flip_camera_ios,
              isActive: false,
              onPressed: onSwitchCamera,
              tooltip: 'Switch Camera',
            ),
          ],

          const SizedBox(width: 16),
          // End Call Button
          FloatingActionButton(
            heroTag: 'end_call_fab',
            backgroundColor: Colors.redAccent,
            elevation: 4,
            onPressed: onEndCall,
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? Colors.white : Colors.white.withValues(alpha: 0.2),
        foregroundColor: isActive ? Colors.black87 : Colors.white,
        padding: const EdgeInsets.all(12),
      ),
      icon: Icon(icon, size: 24),
    );
  }
}
