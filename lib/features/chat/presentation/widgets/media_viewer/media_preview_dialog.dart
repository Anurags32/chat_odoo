import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nspl_odoo/core/theme/app_colors.dart';
import 'package:nspl_odoo/features/chat/domain/models/channel_model.dart';

class MediaPreviewDialog extends StatefulWidget {
  final MessageAttachment attachment;
  final Function(String caption, MessageAttachment attachment) onSend;

  const MediaPreviewDialog({
    super.key,
    required this.attachment,
    required this.onSend,
  });

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _send() {
    widget.onSend(_captionController.text.trim(), widget.attachment);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (widget.attachment.isImage &&
        widget.attachment.data != null &&
        widget.attachment.data!.isNotEmpty) {
      try {
        final clean = widget.attachment.data!.contains(',')
            ? widget.attachment.data!.split(',').last
            : widget.attachment.data!;
        imageProvider = MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.attachment.filename,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: imageProvider != null
                  ? Image(image: imageProvider, fit: BoxFit.contain)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.attachment.isVideo
                              ? Icons.videocam_rounded
                              : Icons.insert_drive_file_rounded,
                          size: 64,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.attachment.filename,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.attachment.formattedSize,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Bottom Caption & Send Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black87,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white60),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    onPressed: _send,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.send_rounded, color: Colors.white),
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
