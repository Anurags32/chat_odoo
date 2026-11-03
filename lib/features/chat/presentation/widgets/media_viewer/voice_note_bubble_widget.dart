import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

class VoiceNoteBubbleWidget extends StatefulWidget {
  final MessageAttachment attachment;
  final bool isMe;

  const VoiceNoteBubbleWidget({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  State<VoiceNoteBubbleWidget> createState() => _VoiceNoteBubbleWidgetState();
}

class _VoiceNoteBubbleWidgetState extends State<VoiceNoteBubbleWidget> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      if (widget.attachment.data != null &&
          widget.attachment.data!.isNotEmpty) {
        final clean = widget.attachment.data!.contains(',')
            ? widget.attachment.data!.split(',').last
            : widget.attachment.data!;
        final bytes = base64Decode(clean);
        await _player.play(BytesSource(bytes));
      } else if (widget.attachment.url != null &&
          widget.attachment.url!.isNotEmpty) {
        await _player.play(UrlSource(widget.attachment.url!));
      }
      await _player.setPlaybackRate(_playbackRate);
    }
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    _player.setPlaybackRate(_playbackRate);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlaying = _playerState == PlayerState.playing;

    final progressRatio = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.12)
            : (isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.lightSurfaceElevated),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Play / Pause Circle
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? AppColors.primary : Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Waveform / Progress Slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simulated Waveform Bars
                SizedBox(
                  height: 22,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(24, (index) {
                      final barProgress = index / 24.0;
                      final isFilled = barProgress <= progressRatio;
                      final barHeights = [
                        8.0,
                        14.0,
                        18.0,
                        10.0,
                        16.0,
                        22.0,
                        12.0,
                        18.0,
                        20.0,
                        14.0,
                        16.0,
                        22.0,
                        18.0,
                        12.0,
                        16.0,
                        20.0,
                        14.0,
                        10.0,
                        18.0,
                        16.0,
                        12.0,
                        14.0,
                        18.0,
                        8.0,
                      ];
                      final height = barHeights[index % barHeights.length];

                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? (widget.isMe ? Colors.white : AppColors.primary)
                              : (widget.isMe
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : (isDark
                                          ? Colors.white24
                                          : Colors.black12)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),

                // Time Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _position.inSeconds > 0
                          ? _formatDuration(_position)
                          : (_duration.inSeconds > 0
                                ? _formatDuration(_duration)
                                : '00:00'),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isMe
                            ? Colors.white70
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                      ),
                    ),
                    if (widget.attachment.formattedSize.isNotEmpty)
                      Text(
                        widget.attachment.formattedSize,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? Colors.white54
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Speed Cycle Chip
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isDark ? Colors.white12 : Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_playbackRate}x',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.isMe
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
