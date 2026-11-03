import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/attachment_service.dart';
import '../../data/services/voice_service.dart';
import '../../domain/models/channel_model.dart';
import 'emoji_picker_widget.dart';
import 'media_viewer/media_preview_dialog.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(MessageAttachment attachment, {String? caption})? onSendAttachment;
  final bool enabled;
  final ChatMessageModel? replyingToMessage;
  final VoidCallback? onCancelReply;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onSendAttachment,
    this.enabled = true,
    this.replyingToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with SingleTickerProviderStateMixin {
  bool _hasText = false;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  // Voice recording state
  bool _isRecording = false;
  bool _isLocked = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  double _currentAmplitude = 0.1;
  StreamSubscription? _ampSub;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recordTimer?.cancel();
    _ampSub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _toggleEmojiKeyboard() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      emoji,
    );
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.start < 0 ? text.length : selection.start) + emoji.length,
      ),
    );
  }

  void _onEmojiBackspace() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (text.isEmpty) return;
    if (selection.start > 0) {
      final newText = text.replaceRange(selection.start - 1, selection.end, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start - 1),
      );
    }
  }

  // ── Voice Recording Methods ──────────────────────────────────────────────

  Future<void> _startRecording() async {
    final started = await VoiceService.instance.startRecording();
    if (!started) return;

    setState(() {
      _isRecording = true;
      _isLocked = false;
      _recordSeconds = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });

    _ampSub?.cancel();
    _ampSub = VoiceService.instance.onAmplitude.listen((amp) {
      if (mounted) setState(() => _currentAmplitude = amp);
    });
  }

  Future<void> _finishRecordingAndSend() async {
    _recordTimer?.cancel();
    _ampSub?.cancel();
    final attachment = await VoiceService.instance.stopRecording();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _recordSeconds = 0;
    });

    if (attachment != null) {
      widget.onSendAttachment?.call(attachment);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _ampSub?.cancel();
    await VoiceService.instance.cancelRecording();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _recordSeconds = 0;
    });
  }

  // ── Attachment Pickers ───────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final attachment = await AttachmentService.instance.pickImage(source: source);
    if (attachment == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewDialog(
          attachment: attachment,
          onSend: (caption, att) {
            widget.onSendAttachment?.call(att, caption: caption);
          },
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    final attachment = await AttachmentService.instance.pickDocument();
    if (attachment != null) {
      widget.onSendAttachment?.call(attachment);
    }
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.photo_library_rounded,
                      color: AppColors.primary,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.camera_alt_rounded,
                      color: AppColors.accentTeal,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.insert_drive_file_rounded,
                      color: AppColors.accentOrange,
                      label: 'Document',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.mic_rounded,
                      color: AppColors.online,
                      label: 'Voice Note',
                      onTap: () {
                        Navigator.pop(ctx);
                        _startRecording();
                        setState(() => _isLocked = true);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reply Banner ─────────────────────────────────────────────────────────

  Widget _buildReplyBanner(bool isDark) {
    if (widget.replyingToMessage == null) return const SizedBox.shrink();

    final clean = widget.replyingToMessage!.cleanBody;
    final snippet = clean.isNotEmpty
        ? clean
        : (widget.replyingToMessage!.attachments.isNotEmpty
            ? widget.replyingToMessage!.attachments.first.filename
            : 'Attachment');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          left: const BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingToMessage!.author.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  // ── Active Recording UI ──────────────────────────────────────────────────

  Widget _buildRecordingBar(bool isDark) {
    final minutes = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        // Blinking Red Dot
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),

        // Timer
        Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 12),

        // Dynamic Waveform animation
        Expanded(
          child: SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(14, (i) {
                final barH = (16.0 * _currentAmplitude * ((i % 3) + 1) / 3.0)
                    .clamp(4.0, 20.0);
                return Container(
                  width: 3,
                  height: barH,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Cancel trash
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: _cancelRecording,
        ),

        // Send Voice
        FloatingActionButton.small(
          heroTag: 'send_voice_note_btn',
          backgroundColor: AppColors.primary,
          onPressed: _finishRecordingAndSend,
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyBanner(isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: _isRecording
                ? _buildRecordingBar(isDark)
                : Row(
                    children: [
                      // Emoji button
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        onPressed: widget.enabled ? _toggleEmojiKeyboard : null,
                      ),

                      // Text Field Container
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.lightSurfaceElevated,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: _focusNode,
                                  enabled: widget.enabled,
                                  decoration: InputDecoration(
                                    hintText: 'Message...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 15,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 10),
                                    isDense: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 4,
                                  minLines: 1,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                ),
                              ),
                              // Attachment (+) icon inside input
                              IconButton(
                                icon: const Icon(Icons.attach_file_rounded),
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                onPressed:
                                    widget.enabled ? _showAttachmentMenu : null,
                              ),
                              if (!_hasText)
                                IconButton(
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  onPressed: widget.enabled
                                      ? () => _pickImage(ImageSource.camera)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action Button (Send or Mic)
                      if (_hasText)
                        GestureDetector(
                          onTap: widget.enabled ? widget.onSend : null,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.buttonGradient,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onLongPress: widget.enabled ? _startRecording : null,
                          onLongPressEnd: (_) => _finishRecordingAndSend(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        // Emoji Picker View
        if (_showEmojiPicker)
          EmojiPickerWidget(
            onEmojiSelected: _onEmojiSelected,
            onBackspace: _onEmojiBackspace,
          ),
      ],
    );
  }
}
