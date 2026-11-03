import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../domain/models/channel_model.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get onAmplitude => _amplitudeController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Check and request microphone permission
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording voice message
  Future<bool> startRecording() async {
    try {
      final hasPerm = await checkPermission();
      if (!hasPerm) return false;

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      _recordingStartTime = DateTime.now();

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        // amp.current is in dB, typically -60 to 0
        final normalized = (amp.current + 60) / 60;
        final clamped = normalized.clamp(0.05, 1.0);
        _amplitudeController.add(clamped);
      });

      return true;
    } catch (e) {
      debugPrint('[VoiceService] startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and produce MessageAttachment with base64 data
  Future<MessageAttachment?> stopRecording() async {
    try {
      _amplitudeSubscription?.cancel();
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final durationSec = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;

      // Discard very short recordings (< 1 second)
      if (durationSec < 1) {
        await file.delete();
        return null;
      }

      final base64String = base64Encode(bytes);
      final filename =
          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      return MessageAttachment(
        filename: filename,
        mimetype: 'audio/m4a',
        data: base64String,
        fileSize: bytes.length,
      );
    } catch (e) {
      debugPrint('[VoiceService] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel and discard the current recording
  Future<void> cancelRecording() async {
    try {
      _amplitudeSubscription?.cancel();
      _isRecording = false;
      await _audioRecorder.cancel();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[VoiceService] cancelRecording error: $e');
    }
  }

  /// Audio Player Controller Helpers
  AudioPlayer get player => _audioPlayer;

  Future<void> playAttachment(MessageAttachment attachment) async {
    try {
      if (attachment.data != null && attachment.data!.isNotEmpty) {
        final clean = attachment.data!.contains(',')
            ? attachment.data!.split(',').last
            : attachment.data!;
        final bytes = base64Decode(clean);
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(bytes));
      } else if (attachment.url != null && attachment.url!.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(attachment.url!));
      }
    } catch (e) {
      debugPrint('[VoiceService] playAttachment error: $e');
    }
  }

  void dispose() {
    _amplitudeSubscription?.cancel();
    _amplitudeController.close();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}

